import 'package:deen_companion/core/error/exceptions.dart';
import 'package:deen_companion/core/error/failures.dart';
import 'package:deen_companion/core/usecase/usecase.dart';
import 'package:deen_companion/features/mutashabihat/data/datasources/mutashabihat_remote_datasource.dart';
import 'package:deen_companion/features/mutashabihat/data/models/mutashabihat_entry_model.dart';
import 'package:deen_companion/features/mutashabihat/data/models/mutashabihat_info_model.dart';
import 'package:deen_companion/features/mutashabihat/data/models/mutashabihat_surah_page_model.dart';
import 'package:deen_companion/features/mutashabihat/data/repositories/mutashabihat_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../_support/cache_test_support.dart';
import '../../../_support/mutashabihat_fixtures.dart';

class MockRemote extends Mock implements MutashabihatRemoteDataSource {}

T ok<T>(Result<T> r) => (r as Success<T>).data;
Failure fail<T>(Result<T> r) => (r as Error<T>).failure;

void main() {
  late MockRemote remote;
  late InMemoryStorage storage;
  late FakeNetworkInfo network;
  late MutashabihatRepositoryImpl repo;

  setUp(() {
    remote = MockRemote();
    storage = InMemoryStorage();
    network = FakeNetworkInfo();
    repo = MutashabihatRepositoryImpl(
      remoteDataSource: remote,
      cacheStore: storeFor(storage),
      networkInfo: network,
    );
  });

  group('info', () {
    test('fetch caches; getCachedInfo reads back', () async {
      when(
        () => remote.getInfo(),
      ).thenAnswer((_) async => MutashabihatInfoModel.fromJson(infoJson()));
      expect(repo.getCachedInfo(), isNull);

      expect(ok(await repo.fetchAndCacheInfo()).totalPairs, 2500);
      expect(repo.getCachedInfo()!.surahsInvolved, 110);
    });

    test('90 day TTL', () async {
      storage.seed(
        'mutashabihat_info',
        infoJson(),
        age: const Duration(days: 89),
      );
      ok(await repo.fetchAndCacheInfo());
      verifyZeroInteractions(remote);

      storage.seed(
        'mutashabihat_info',
        infoJson(),
        age: const Duration(days: 91),
      );
      when(
        () => remote.getInfo(),
      ).thenAnswer((_) async => MutashabihatInfoModel.fromJson(infoJson()));
      ok(await repo.fetchAndCacheInfo());
      verify(() => remote.getInfo()).called(1);
    });

    test('offline / server / unexpected', () async {
      network.connected = false;
      expect(fail(await repo.fetchAndCacheInfo()), isA<NetworkFailure>());
      storage.seed(
        'mutashabihat_info',
        infoJson(),
        age: const Duration(days: 200),
      );
      expect(ok(await repo.fetchAndCacheInfo()).totalEntries, 1000);

      network.connected = true;
      when(() => remote.getInfo()).thenThrow(const ServerException('s'));
      expect(ok(await repo.fetchAndCacheInfo()).totalEntries, 1000);

      storage.boxes.clear();
      expect(fail(await repo.fetchAndCacheInfo()).message, 's');
      when(() => remote.getInfo()).thenThrow(StateError('x'));
      expect(fail(await repo.fetchAndCacheInfo()), isA<UnexpectedFailure>());
    });
  });

  group('random', () {
    test('is never cached and requires network', () async {
      when(
        () => remote.getRandom(),
      ).thenAnswer((_) async => MutashabihatEntryModel.fromJson(entryJson()));

      ok(await repo.fetchRandom());
      ok(await repo.fetchRandom());

      verify(() => remote.getRandom()).called(2);
      expect(storage.boxes, isEmpty);
    });

    test('offline -> NetworkFailure without calling remote', () async {
      network.connected = false;
      expect(fail(await repo.fetchRandom()), isA<NetworkFailure>());
      verifyZeroInteractions(remote);
    });

    test('server error and unexpected error', () async {
      when(() => remote.getRandom()).thenThrow(const ServerException('r'));
      expect(fail(await repo.fetchRandom()).message, 'r');
      when(() => remote.getRandom()).thenThrow(StateError('x'));
      expect(fail(await repo.fetchRandom()), isA<UnexpectedFailure>());
    });
  });

  group('byAyah', () {
    test('network success is cached per ayah key', () async {
      when(
        () => remote.getByAyah(2, 1),
      ).thenAnswer((_) async => MutashabihatEntryModel.fromJson(entryJson()));

      final e = ok(await repo.fetchByAyah(2, 1));

      expect(e.similarVerses, hasLength(2));
      expect(storage.hasCached('mutashabihat_ayah_2_1'), isTrue);
      expect(storage.hasCached('mutashabihat_ayah_2_2'), isFalse);
    });

    test(
      'always tries network first even when cached (no TTL short-circuit)',
      () async {
        storage.seed('mutashabihat_ayah_2_1', entryJson(similar: 1));
        when(() => remote.getByAyah(2, 1)).thenAnswer(
          (_) async => MutashabihatEntryModel.fromJson(entryJson(similar: 3)),
        );

        expect(ok(await repo.fetchByAyah(2, 1)).similarVerses, hasLength(3));
      },
    );

    test('offline: cached entry served, else NetworkFailure', () async {
      network.connected = false;
      expect(fail(await repo.fetchByAyah(2, 1)), isA<NetworkFailure>());

      storage.seed('mutashabihat_ayah_2_1', entryJson(similar: 1));
      expect(ok(await repo.fetchByAyah(2, 1)).similarVerses, hasLength(1));
    });

    test(
      'NotFoundException maps to NotFoundFailure and ignores any cache',
      () async {
        storage.seed('mutashabihat_ayah_2_1', entryJson());
        when(() => remote.getByAyah(2, 1)).thenThrow(const NotFoundException());

        final f = fail(await repo.fetchByAyah(2, 1));

        expect(f, isA<NotFoundFailure>());
        expect(f.message, 'No similar verses are known for this ayah.');
      },
    );

    test('ServerException falls back to cache else ServerFailure', () async {
      when(
        () => remote.getByAyah(2, 1),
      ).thenThrow(const ServerException('bad'));
      expect(fail(await repo.fetchByAyah(2, 1)).message, 'bad');

      storage.seed('mutashabihat_ayah_2_1', entryJson(similar: 1));
      expect(ok(await repo.fetchByAyah(2, 1)).similarVerses, hasLength(1));
    });

    test('unexpected error -> UnexpectedFailure', () async {
      when(() => remote.getByAyah(any(), any())).thenThrow(StateError('x'));
      expect(fail(await repo.fetchByAyah(2, 1)), isA<UnexpectedFailure>());
    });
  });

  group('surah page', () {
    test('fetch caches under surah+page key', () async {
      when(() => remote.getSurahPage(2, 1)).thenAnswer(
        (_) async => MutashabihatSurahPageModel.fromJson(surahPageJson()),
      );

      final p = ok(await repo.fetchSurahPage(2, 1));

      expect(p.hasMore, isTrue);
      expect(storage.hasCached('mutashabihat_surah_2_page_1'), isTrue);
    });

    test('fresh cache avoids network; forceRefresh bypasses it', () async {
      storage.seed('mutashabihat_surah_2_page_1', surahPageJson());
      ok(await repo.fetchSurahPage(2, 1));
      verifyZeroInteractions(remote);

      when(() => remote.getSurahPage(2, 1)).thenAnswer(
        (_) async =>
            MutashabihatSurahPageModel.fromJson(surahPageJson(count: 1)),
      );
      expect(
        ok(await repo.fetchSurahPage(2, 1, forceRefresh: true)).entries,
        hasLength(1),
      );
    });

    test('stale (90d) cache refetches', () async {
      storage.seed(
        'mutashabihat_surah_2_page_1',
        surahPageJson(),
        age: const Duration(days: 91),
      );
      when(() => remote.getSurahPage(2, 1)).thenAnswer(
        (_) async =>
            MutashabihatSurahPageModel.fromJson(surahPageJson(count: 1)),
      );
      expect(ok(await repo.fetchSurahPage(2, 1)).entries, hasLength(1));
    });

    test('offline/server/unexpected paths', () async {
      network.connected = false;
      expect(fail(await repo.fetchSurahPage(2, 1)), isA<NetworkFailure>());
      storage.seed(
        'mutashabihat_surah_2_page_1',
        surahPageJson(),
        age: const Duration(days: 200),
      );
      expect(ok(await repo.fetchSurahPage(2, 1)).entries, hasLength(2));

      network.connected = true;
      when(
        () => remote.getSurahPage(2, 1),
      ).thenThrow(const ServerException('s'));
      expect(ok(await repo.fetchSurahPage(2, 1)).entries, hasLength(2));

      storage.boxes.clear();
      expect(fail(await repo.fetchSurahPage(2, 1)).message, 's');
      when(() => remote.getSurahPage(2, 1)).thenThrow(StateError('x'));
      expect(fail(await repo.fetchSurahPage(2, 1)), isA<UnexpectedFailure>());
    });
  });
}
