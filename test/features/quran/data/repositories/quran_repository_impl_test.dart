import 'package:deen_companion/core/error/exceptions.dart';
import 'package:deen_companion/core/error/failures.dart';
import 'package:deen_companion/core/usecase/usecase.dart';
import 'package:deen_companion/features/quran/data/datasources/quran_remote_datasource.dart';
import 'package:deen_companion/features/quran/data/models/juz_model.dart';
import 'package:deen_companion/features/quran/data/models/mushaf_page_model.dart';
import 'package:deen_companion/features/quran/data/models/quran_meta_model.dart';
import 'package:deen_companion/features/quran/data/models/search_response_model.dart';
import 'package:deen_companion/features/quran/data/models/surah_summary_model.dart';
import 'package:deen_companion/features/quran/data/repositories/quran_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../_support/cache_test_support.dart';
import '../../../_support/quran_fixtures.dart';

class MockRemote extends Mock implements QuranRemoteDataSource {}

T ok<T>(Result<T> r) => (r as Success<T>).data;
Failure fail<T>(Result<T> r) => (r as Error<T>).failure;

void main() {
  late MockRemote remote;
  late InMemoryStorage storage;
  late FakeNetworkInfo network;
  late QuranRepositoryImpl repo;

  setUp(() {
    remote = MockRemote();
    storage = InMemoryStorage();
    network = FakeNetworkInfo();
    repo = QuranRepositoryImpl(
      remoteDataSource: remote,
      cacheStore: storeFor(storage),
      networkInfo: network,
    );
  });

  group('quran meta', () {
    test('cache miss: fetches, caches and returns entity', () async {
      when(
        () => remote.getQuranMeta(),
      ).thenAnswer((_) async => QuranMetaModel.fromJson(metaJson()));

      final meta = ok(await repo.fetchAndCacheQuranMeta());

      expect(meta.totalSurahs, 114);
      expect(storage.hasCached('quran_meta'), isTrue);
      expect(repo.getCachedQuranMeta()?.totalVerses, 6236);
    });

    test('fresh cache is returned without touching network', () async {
      storage.seed('quran_meta', metaJson(surahs: 100));

      final meta = ok(await repo.fetchAndCacheQuranMeta());

      expect(meta.totalSurahs, 100);
      verifyZeroInteractions(remote);
    });

    test('stale cache (older than 12h) triggers a refetch', () async {
      storage.seed(
        'quran_meta',
        metaJson(surahs: 100),
        age: const Duration(hours: 13),
      );
      when(
        () => remote.getQuranMeta(),
      ).thenAnswer((_) async => QuranMetaModel.fromJson(metaJson()));

      expect(ok(await repo.fetchAndCacheQuranMeta()).totalSurahs, 114);
      verify(() => remote.getQuranMeta()).called(1);
    });

    test('cache just inside TTL is still fresh', () async {
      storage.seed(
        'quran_meta',
        metaJson(surahs: 100),
        age: const Duration(hours: 11),
      );
      expect(ok(await repo.fetchAndCacheQuranMeta()).totalSurahs, 100);
      verifyZeroInteractions(remote);
    });

    test('forceRefresh bypasses a fresh cache', () async {
      storage.seed('quran_meta', metaJson(surahs: 100));
      when(
        () => remote.getQuranMeta(),
      ).thenAnswer((_) async => QuranMetaModel.fromJson(metaJson()));

      final meta = ok(await repo.fetchAndCacheQuranMeta(forceRefresh: true));

      expect(meta.totalSurahs, 114);
      expect(repo.getCachedQuranMeta()!.totalSurahs, 114);
    });

    test('offline with no cache returns NetworkFailure', () async {
      network.connected = false;
      final f = fail(await repo.fetchAndCacheQuranMeta());
      expect(f, isA<NetworkFailure>());
      verifyZeroInteractions(remote);
    });

    test('offline with stale cache serves the stale cache', () async {
      network.connected = false;
      storage.seed(
        'quran_meta',
        metaJson(surahs: 100),
        age: const Duration(days: 5),
      );
      expect(ok(await repo.fetchAndCacheQuranMeta()).totalSurahs, 100);
    });

    test('ServerException with stale cache falls back to cache', () async {
      storage.seed(
        'quran_meta',
        metaJson(surahs: 100),
        age: const Duration(days: 5),
      );
      when(() => remote.getQuranMeta()).thenThrow(const ServerException('x'));
      expect(ok(await repo.fetchAndCacheQuranMeta()).totalSurahs, 100);
    });

    test(
      'ServerException without cache returns ServerFailure with message',
      () async {
        when(
          () => remote.getQuranMeta(),
        ).thenThrow(const ServerException('bad gateway'));
        final f = fail(await repo.fetchAndCacheQuranMeta());
        expect(f, isA<ServerFailure>());
        expect(f.message, 'bad gateway');
      },
    );

    test('ServerException without message uses default message', () async {
      when(() => remote.getQuranMeta()).thenThrow(const ServerException());
      final f = fail(await repo.fetchAndCacheQuranMeta());
      expect(f.message, const ServerFailure().message);
    });

    test('unexpected error (bad payload) maps to UnexpectedFailure', () async {
      when(() => remote.getQuranMeta()).thenThrow(StateError('parse'));
      expect(
        fail(await repo.fetchAndCacheQuranMeta()),
        isA<UnexpectedFailure>(),
      );
    });
  });

  group('surah list', () {
    test('getCachedSurahList is null when nothing cached', () {
      expect(repo.getCachedSurahList(), isNull);
    });

    test('fetch caches list and round-trips through cache', () async {
      when(() => remote.getSurahList()).thenAnswer(
        (_) async => [
          SurahSummaryModel.fromJson(surahJson(number: 1)),
          SurahSummaryModel.fromJson(
            surahJson(number: 2, english: 'Al-Baqarah'),
          ),
        ],
      );

      final fetched = ok(await repo.fetchAndCacheSurahList());
      final cached = repo.getCachedSurahList()!;

      expect(fetched.map((s) => s.number), [1, 2]);
      expect(cached.map((s) => s.nameEnglish), ['Al-Fatihah', 'Al-Baqarah']);
      expect(cached.first.exampleAudioUrl, 'https://a/1.mp3');
    });

    test('fresh cache avoids network; stale cache refetches', () async {
      storage.seedList('quran_surah_list', [surahJson(number: 9)]);
      expect(ok(await repo.fetchAndCacheSurahList()).single.number, 9);
      verifyZeroInteractions(remote);

      storage.seedList('quran_surah_list', [
        surahJson(number: 9),
      ], age: const Duration(hours: 13));
      when(() => remote.getSurahList()).thenAnswer(
        (_) async => [SurahSummaryModel.fromJson(surahJson(number: 1))],
      );
      expect(ok(await repo.fetchAndCacheSurahList()).single.number, 1);
    });

    test('offline paths', () async {
      network.connected = false;
      expect(fail(await repo.fetchAndCacheSurahList()), isA<NetworkFailure>());

      storage.seedList('quran_surah_list', [
        surahJson(number: 3),
      ], age: const Duration(days: 2));
      expect(ok(await repo.fetchAndCacheSurahList()).single.number, 3);
    });

    test('server error falls back to cache, else ServerFailure', () async {
      when(
        () => remote.getSurahList(),
      ).thenThrow(const ServerException('down'));
      expect(fail(await repo.fetchAndCacheSurahList()).message, 'down');

      storage.seedList('quran_surah_list', [
        surahJson(number: 3),
      ], age: const Duration(days: 2));
      expect(ok(await repo.fetchAndCacheSurahList()).single.number, 3);
    });

    test('unexpected error maps to UnexpectedFailure', () async {
      when(() => remote.getSurahList()).thenThrow(Exception('weird'));
      expect(
        fail(await repo.fetchAndCacheSurahList()),
        isA<UnexpectedFailure>(),
      );
    });
  });

  group('juz', () {
    test('cache keys are per-number', () async {
      when(
        () => remote.getJuz(1),
      ).thenAnswer((_) async => JuzModel.fromJson(juzJson(number: 1)));
      when(
        () => remote.getJuz(2),
      ).thenAnswer((_) async => JuzModel.fromJson(juzJson(number: 2)));

      await repo.fetchAndCacheJuz(1);
      expect(repo.getCachedJuz(1)?.juzNumber, 1);
      expect(repo.getCachedJuz(2), isNull);

      await repo.fetchAndCacheJuz(2);
      expect(repo.getCachedJuz(2)?.juzNumber, 2);
      expect(storage.hasCached('quran_juz_1'), isTrue);
      expect(storage.hasCached('quran_juz_2'), isTrue);
    });

    test('30 day TTL: 29 days is fresh, 31 days is stale', () async {
      storage.seed(
        'quran_juz_4',
        juzJson(number: 4),
        age: const Duration(days: 29),
      );
      expect(ok(await repo.fetchAndCacheJuz(4)).juzNumber, 4);
      verifyZeroInteractions(remote);

      storage.seed(
        'quran_juz_4',
        juzJson(number: 4),
        age: const Duration(days: 31),
      );
      when(
        () => remote.getJuz(4),
      ).thenAnswer((_) async => JuzModel.fromJson(juzJson(number: 4)));
      await repo.fetchAndCacheJuz(4);
      verify(() => remote.getJuz(4)).called(1);
    });

    test('error paths: offline, server, unexpected', () async {
      network.connected = false;
      expect(fail(await repo.fetchAndCacheJuz(1)), isA<NetworkFailure>());

      network.connected = true;
      when(() => remote.getJuz(1)).thenThrow(const ServerException('s'));
      expect(fail(await repo.fetchAndCacheJuz(1)), isA<ServerFailure>());

      when(() => remote.getJuz(1)).thenThrow(ArgumentError('u'));
      expect(fail(await repo.fetchAndCacheJuz(1)), isA<UnexpectedFailure>());
    });

    test('server error falls back to stale cached juz', () async {
      storage.seed('quran_juz_1', juzJson(), age: const Duration(days: 40));
      when(() => remote.getJuz(1)).thenThrow(const ServerException('s'));
      expect(ok(await repo.fetchAndCacheJuz(1)).verses, hasLength(2));
    });
  });

  group('mushaf page', () {
    test(
      'fetch caches page and exposes wordsByLine after cache read',
      () async {
        when(
          () => remote.getMushafPage(10),
        ).thenAnswer((_) async => MushafPageModel.fromJson(pageJson(page: 10)));

        await repo.fetchAndCacheMushafPage(10);
        final cached = repo.getCachedMushafPage(10)!;

        expect(cached.page, 10);
        expect(cached.wordsByLine[1], hasLength(2));
      },
    );

    test('fresh cache, forceRefresh, and failures', () async {
      storage.seed('quran_page_1', pageJson());
      expect(ok(await repo.fetchAndCacheMushafPage(1)).page, 1);
      verifyZeroInteractions(remote);

      when(
        () => remote.getMushafPage(1),
      ).thenAnswer((_) async => MushafPageModel.fromJson(pageJson(page: 1)));
      await repo.fetchAndCacheMushafPage(1, forceRefresh: true);
      verify(() => remote.getMushafPage(1)).called(1);

      network.connected = false;
      expect(
        ok(await repo.fetchAndCacheMushafPage(1, forceRefresh: true)).page,
        1,
      );

      network.connected = true;
      storage.boxes.clear();
      when(() => remote.getMushafPage(1)).thenThrow(const ServerException('m'));
      expect(fail(await repo.fetchAndCacheMushafPage(1)).message, 'm');
      when(() => remote.getMushafPage(1)).thenThrow(StateError('x'));
      expect(
        fail(await repo.fetchAndCacheMushafPage(1)),
        isA<UnexpectedFailure>(),
      );
    });
  });

  group('search', () {
    SearchResponseModel response() =>
        SearchResponseModel.fromJson(searchResponseJson());

    test('caches results under a lowercase-insensitive key', () async {
      when(
        () => remote.searchQuran(
          'Throne',
          translation: 'sahih_international',
          limit: 25,
        ),
      ).thenAnswer((_) async => response());

      final results = ok(await repo.search('Throne'));
      expect(results.single.verseKey, '2:255');

      // Same query in different case hits the cache, not the network.
      final again = ok(await repo.search('THRONE'));
      expect(again.single.verseKey, '2:255');
      verify(
        () => remote.searchQuran(
          any(),
          translation: any(named: 'translation'),
          limit: any(named: 'limit'),
        ),
      ).called(1);
    });

    test('translation and limit are part of the cache key', () async {
      when(
        () => remote.searchQuran(
          any(),
          translation: any(named: 'translation'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => response());

      await repo.search('a');
      await repo.search('a', translation: 'pickthall');
      await repo.search('a', limit: 5);

      verify(
        () => remote.searchQuran(
          any(),
          translation: any(named: 'translation'),
          limit: any(named: 'limit'),
        ),
      ).called(3);
      expect(repo.getCachedSearchResults('a'), isNotNull);
      expect(
        repo.getCachedSearchResults('a', translation: 'pickthall'),
        isNotNull,
      );
      expect(repo.getCachedSearchResults('zzz'), isNull);
    });

    test('1h TTL: stale results are refetched', () async {
      storage.seedList('quran_search_a_sahih_international_25', [
        searchResultJson(key: '1:1'),
      ], age: const Duration(hours: 2));
      when(
        () => remote.searchQuran(
          'a',
          translation: 'sahih_international',
          limit: 25,
        ),
      ).thenAnswer((_) async => response());

      expect(ok(await repo.search('a')).single.verseKey, '2:255');
    });

    test('empty result set is cached and returned as empty list', () async {
      when(
        () => remote.searchQuran(
          any(),
          translation: any(named: 'translation'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer(
        (_) async => SearchResponseModel.fromJson(
          searchResponseJson()..['results'] = [],
        ),
      );

      expect(ok(await repo.search('nothing')), isEmpty);
      expect(repo.getCachedSearchResults('nothing'), isEmpty);
    });

    test(
      'offline: no cache -> NetworkFailure; stale cache -> served',
      () async {
        network.connected = false;
        expect(fail(await repo.search('a')), isA<NetworkFailure>());

        storage.seedList('quran_search_a_sahih_international_25', [
          searchResultJson(),
        ], age: const Duration(days: 1));
        expect(ok(await repo.search('a')), hasLength(1));
      },
    );

    test('server error falls back to stale cache else ServerFailure', () async {
      when(
        () => remote.searchQuran(
          any(),
          translation: any(named: 'translation'),
          limit: any(named: 'limit'),
        ),
      ).thenThrow(const ServerException('oops'));
      expect(fail(await repo.search('a')).message, 'oops');

      storage.seedList('quran_search_a_sahih_international_25', [
        searchResultJson(),
      ], age: const Duration(days: 1));
      expect(ok(await repo.search('a')), hasLength(1));
    });

    test('unexpected error -> UnexpectedFailure', () async {
      when(
        () => remote.searchQuran(
          any(),
          translation: any(named: 'translation'),
          limit: any(named: 'limit'),
        ),
      ).thenThrow(StateError('x'));
      expect(fail(await repo.search('a')), isA<UnexpectedFailure>());
    });
  });
}
