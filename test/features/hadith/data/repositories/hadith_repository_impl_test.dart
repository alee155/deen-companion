import 'package:deen_companion/core/error/exceptions.dart';
import 'package:deen_companion/core/error/failures.dart';
import 'package:deen_companion/core/usecase/usecase.dart';
import 'package:deen_companion/features/hadith/data/datasources/hadith_remote_datasource.dart';
import 'package:deen_companion/features/hadith/data/models/hadith_collection_model.dart';
import 'package:deen_companion/features/hadith/data/models/hadith_list_page_model.dart';
import 'package:deen_companion/features/hadith/data/models/hadith_model.dart';
import 'package:deen_companion/features/hadith/data/repositories/hadith_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../_support/cache_test_support.dart';
import '../../../_support/hadith_fixtures.dart';

class MockRemote extends Mock implements HadithRemoteDataSource {}

T ok<T>(Result<T> r) => (r as Success<T>).data;
Failure fail<T>(Result<T> r) => (r as Error<T>).failure;

String today([DateTime? d]) {
  final n = d ?? DateTime.now();
  return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
}

void main() {
  late MockRemote remote;
  late InMemoryStorage storage;
  late FakeNetworkInfo network;
  late HadithRepositoryImpl repo;

  setUp(() {
    remote = MockRemote();
    storage = InMemoryStorage();
    network = FakeNetworkInfo();
    repo = HadithRepositoryImpl(
      remoteDataSource: remote,
      cacheStore: storeFor(storage),
      networkInfo: network,
    );
  });

  group('collections', () {
    test('fetch caches list; cached read returns entities', () async {
      when(() => remote.getCollections()).thenAnswer(
        (_) async => [HadithCollectionModel.fromJson(hadithCollectionJson())],
      );
      expect(repo.getCachedCollections(), isNull);

      final list = ok(await repo.fetchAndCacheCollections());

      expect(list.single.key, 'bukhari');
      expect(repo.getCachedCollections()!.single.totalHadiths, 7563);
    });

    test('fresh cache skips network, stale refetches', () async {
      storage.seedList('hadith_collections', [
        hadithCollectionJson(key: 'old'),
      ]);
      expect(ok(await repo.fetchAndCacheCollections()).single.key, 'old');
      verifyZeroInteractions(remote);

      storage.seedList('hadith_collections', [
        hadithCollectionJson(key: 'old'),
      ], age: const Duration(days: 31));
      when(() => remote.getCollections()).thenAnswer(
        (_) async => [
          HadithCollectionModel.fromJson(hadithCollectionJson(key: 'new')),
        ],
      );
      expect(ok(await repo.fetchAndCacheCollections()).single.key, 'new');
    });

    test('offline / server / unexpected error paths', () async {
      network.connected = false;
      expect(
        fail(await repo.fetchAndCacheCollections()),
        isA<NetworkFailure>(),
      );

      network.connected = true;
      when(() => remote.getCollections()).thenThrow(const ServerException('s'));
      expect(fail(await repo.fetchAndCacheCollections()).message, 's');

      storage.seedList('hadith_collections', [
        hadithCollectionJson(),
      ], age: const Duration(days: 40));
      expect(ok(await repo.fetchAndCacheCollections()).single.key, 'bukhari');

      storage.boxes.clear();
      when(() => remote.getCollections()).thenThrow(StateError('x'));
      expect(
        fail(await repo.fetchAndCacheCollections()),
        isA<UnexpectedFailure>(),
      );
    });
  });

  group('hadith pages', () {
    test('getCachedHadithPage is per collection and page', () async {
      when(() => remote.getHadithPage('bukhari', 2)).thenAnswer(
        (_) async => HadithListPageModel.fromJson(hadithPageJson(page: 2)),
      );
      await repo.fetchAndCacheHadithPage('bukhari', 2);

      final cached = repo.getCachedHadithPage('bukhari', 2)!;
      expect(cached.page, 2);
      expect(cached.totalPages, 3);
      expect(cached.hadiths.first.hadithNumber, 51);
      expect(repo.getCachedHadithPage('bukhari', 1), isNull);
      expect(repo.getCachedHadithPage('muslim', 2), isNull);
    });

    test('returns fresh cached page without network', () async {
      storage.seed('hadith_page_bukhari_1', hadithPageJson());
      final r = ok(await repo.fetchAndCacheHadithPage('bukhari', 1));
      expect(r.hadiths, hasLength(2));
      verifyZeroInteractions(remote);
    });

    test('forceRefresh refetches even when fresh', () async {
      storage.seed('hadith_page_bukhari_1', hadithPageJson(count: 1));
      when(() => remote.getHadithPage('bukhari', 1)).thenAnswer(
        (_) async => HadithListPageModel.fromJson(hadithPageJson(count: 2)),
      );
      final r = ok(
        await repo.fetchAndCacheHadithPage('bukhari', 1, forceRefresh: true),
      );
      expect(r.hadiths, hasLength(2));
    });

    test('offline: stale cache served, otherwise NetworkFailure', () async {
      network.connected = false;
      expect(
        fail(await repo.fetchAndCacheHadithPage('bukhari', 1)),
        isA<NetworkFailure>(),
      );

      storage.seed(
        'hadith_page_bukhari_1',
        hadithPageJson(),
        age: const Duration(days: 90),
      );
      expect(
        ok(await repo.fetchAndCacheHadithPage('bukhari', 1)).hadiths,
        hasLength(2),
      );
    });

    test('server error: stale cache fallback, else ServerFailure', () async {
      when(
        () => remote.getHadithPage(any(), any()),
      ).thenThrow(const ServerException('boom'));
      expect(
        fail(await repo.fetchAndCacheHadithPage('bukhari', 1)).message,
        'boom',
      );

      storage.seed(
        'hadith_page_bukhari_1',
        hadithPageJson(),
        age: const Duration(days: 90),
      );
      expect(
        ok(await repo.fetchAndCacheHadithPage('bukhari', 1)).hadiths,
        hasLength(2),
      );
    });

    test('unexpected error -> UnexpectedFailure', () async {
      when(() => remote.getHadithPage(any(), any())).thenThrow(Exception('?'));
      expect(
        fail(await repo.fetchAndCacheHadithPage('bukhari', 1)),
        isA<UnexpectedFailure>(),
      );
    });
  });

  group('daily hadith', () {
    test('same-day cache is reused with no network call', () async {
      storage.seed('hadith_daily', {
        'date': today(),
        'hadith': hadithJson(n: 77),
      });
      expect(ok(await repo.fetchDailyHadith()).hadithNumber, 77);
      verifyZeroInteractions(remote);
    });

    test(
      'previous-day cache triggers a new random fetch and re-cache',
      () async {
        final yesterday = today(
          DateTime.now().subtract(const Duration(days: 1)),
        );
        storage.seed('hadith_daily', {
          'date': yesterday,
          'hadith': hadithJson(n: 1),
        });
        when(
          () => remote.getRandomHadith(),
        ).thenAnswer((_) async => HadithModel.fromJson(hadithJson(n: 2)));

        expect(ok(await repo.fetchDailyHadith()).hadithNumber, 2);

        final stored = storage.boxes.values.single['hadith_daily'] as Map;
        expect((stored['data'] as Map)['date'], today());
        expect(((stored['data'] as Map)['hadith'] as Map)['hadithnumber'], 2);
      },
    );

    test('new day + offline shows yesterday\'s hadith', () async {
      network.connected = false;
      storage.seed('hadith_daily', {
        'date': '2000-01-01',
        'hadith': hadithJson(n: 5),
      });
      expect(ok(await repo.fetchDailyHadith()).hadithNumber, 5);
    });

    test('offline with no cache -> NetworkFailure', () async {
      network.connected = false;
      expect(fail(await repo.fetchDailyHadith()), isA<NetworkFailure>());
    });

    test('server error: old cache fallback, else ServerFailure', () async {
      when(
        () => remote.getRandomHadith(),
      ).thenThrow(const ServerException('x'));
      expect(fail(await repo.fetchDailyHadith()).message, 'x');

      storage.seed('hadith_daily', {
        'date': '2000-01-01',
        'hadith': hadithJson(n: 5),
      });
      expect(ok(await repo.fetchDailyHadith()).hadithNumber, 5);
    });

    test(
      'fetched hadith is cached for today so a second call is free',
      () async {
        when(
          () => remote.getRandomHadith(),
        ).thenAnswer((_) async => HadithModel.fromJson(hadithJson(n: 9)));

        await repo.fetchDailyHadith();
        final second = ok(await repo.fetchDailyHadith());

        expect(second.hadithNumber, 9);
        verify(() => remote.getRandomHadith()).called(1);
      },
    );

    test('unexpected error -> UnexpectedFailure', () async {
      when(() => remote.getRandomHadith()).thenThrow(StateError('x'));
      expect(fail(await repo.fetchDailyHadith()), isA<UnexpectedFailure>());
    });
  });

  group('search', () {
    test('caches per query/collection/limit', () async {
      when(
        () => remote.search(
          any(),
          collection: any(named: 'collection'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => [HadithModel.fromJson(hadithJson())]);

      await repo.search('Intent');
      await repo.search('intent'); // same key, lowercased
      await repo.search('intent', collection: 'muslim'); // different key
      await repo.search('intent', limit: 5); // different key

      verify(
        () => remote.search(
          any(),
          collection: any(named: 'collection'),
          limit: any(named: 'limit'),
        ),
      ).called(3);
    });

    test('stale cache refetches; fresh cache is used', () async {
      storage.seedList('hadith_search_a_all_25', [hadithJson(n: 1)]);
      expect(ok(await repo.search('a')).single.hadithNumber, 1);
      verifyZeroInteractions(remote);

      storage.seedList('hadith_search_a_all_25', [
        hadithJson(n: 1),
      ], age: const Duration(hours: 2));
      when(
        () => remote.search('a', collection: null, limit: 25),
      ).thenAnswer((_) async => [HadithModel.fromJson(hadithJson(n: 2))]);
      expect(ok(await repo.search('a')).single.hadithNumber, 2);
    });

    test('offline paths', () async {
      network.connected = false;
      expect(fail(await repo.search('a')), isA<NetworkFailure>());
      storage.seedList('hadith_search_a_all_25', [
        hadithJson(n: 3),
      ], age: const Duration(days: 1));
      expect(ok(await repo.search('a')).single.hadithNumber, 3);
    });

    test(
      'server error: stale fallback else ServerFailure; unexpected -> UnexpectedFailure',
      () async {
        when(
          () => remote.search(
            any(),
            collection: any(named: 'collection'),
            limit: any(named: 'limit'),
          ),
        ).thenThrow(const ServerException('bad'));
        expect(fail(await repo.search('a')).message, 'bad');

        storage.seedList('hadith_search_a_all_25', [
          hadithJson(n: 3),
        ], age: const Duration(days: 1));
        expect(ok(await repo.search('a')).single.hadithNumber, 3);

        storage.boxes.clear();
        when(
          () => remote.search(
            any(),
            collection: any(named: 'collection'),
            limit: any(named: 'limit'),
          ),
        ).thenThrow(StateError('x'));
        expect(fail(await repo.search('a')), isA<UnexpectedFailure>());
      },
    );
  });
}
