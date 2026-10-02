import 'package:deen_companion/core/error/exceptions.dart';
import 'package:deen_companion/core/error/failures.dart';
import 'package:deen_companion/core/usecase/usecase.dart';
import 'package:deen_companion/features/duas/data/datasources/dua_remote_datasource.dart';
import 'package:deen_companion/features/duas/data/models/dua_search_response_model.dart';
import 'package:deen_companion/features/duas/data/models/duas_bundle_model.dart';
import 'package:deen_companion/features/duas/data/repositories/dua_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../_support/cache_test_support.dart';
import '../../../_support/dua_fixtures.dart';

class MockRemote extends Mock implements DuaRemoteDataSource {}

T ok<T>(Result<T> r) => (r as Success<T>).data;
Failure fail<T>(Result<T> r) => (r as Error<T>).failure;

void main() {
  late MockRemote remote;
  late InMemoryStorage storage;
  late FakeNetworkInfo network;
  late DuaRepositoryImpl repo;

  setUp(() {
    remote = MockRemote();
    storage = InMemoryStorage();
    network = FakeNetworkInfo();
    repo = DuaRepositoryImpl(
      remoteDataSource: remote,
      cacheStore: storeFor(storage),
      networkInfo: network,
    );
  });

  group('bundle', () {
    test('getCachedBundle is null on empty cache', () {
      expect(repo.getCachedBundle(), isNull);
    });

    test('fetches, caches and returns bundle', () async {
      when(
        () => remote.getBundle(),
      ).thenAnswer((_) async => DuasBundleModel.fromJson(bundleJson()));

      final bundle = ok(await repo.fetchAndCacheBundle());

      expect(bundle.duas, hasLength(3));
      expect(repo.getCachedBundle()!.byCategory('morning'), hasLength(2));
    });

    test('30 day TTL: 29d fresh, 31d stale', () async {
      storage.seed('duas_bundle', bundleJson(), age: const Duration(days: 29));
      ok(await repo.fetchAndCacheBundle());
      verifyZeroInteractions(remote);

      storage.seed('duas_bundle', bundleJson(), age: const Duration(days: 31));
      when(
        () => remote.getBundle(),
      ).thenAnswer((_) async => DuasBundleModel.fromJson(bundleJson()));
      ok(await repo.fetchAndCacheBundle());
      verify(() => remote.getBundle()).called(1);
    });

    test('forceRefresh bypasses fresh cache', () async {
      storage.seed('duas_bundle', bundleJson());
      when(
        () => remote.getBundle(),
      ).thenAnswer((_) async => DuasBundleModel.fromJson(bundleJson()));
      ok(await repo.fetchAndCacheBundle(forceRefresh: true));
      verify(() => remote.getBundle()).called(1);
    });

    test('offline without cache -> NetworkFailure', () async {
      network.connected = false;
      expect(fail(await repo.fetchAndCacheBundle()), isA<NetworkFailure>());
    });

    test('offline with stale cache serves it', () async {
      network.connected = false;
      storage.seed('duas_bundle', bundleJson(), age: const Duration(days: 60));
      expect(ok(await repo.fetchAndCacheBundle()).duas, hasLength(3));
    });

    test('server error -> cache fallback or ServerFailure(message)', () async {
      when(() => remote.getBundle()).thenThrow(const ServerException('nope'));
      final f = fail(await repo.fetchAndCacheBundle());
      expect(f, isA<ServerFailure>());
      expect(f.message, 'nope');

      storage.seed('duas_bundle', bundleJson(), age: const Duration(days: 60));
      expect(ok(await repo.fetchAndCacheBundle()).duas, hasLength(3));
    });

    test('unexpected error -> UnexpectedFailure', () async {
      when(() => remote.getBundle()).thenThrow(StateError('x'));
      expect(fail(await repo.fetchAndCacheBundle()), isA<UnexpectedFailure>());
    });
  });

  group('search', () {
    test('fetches, caches by lowercase query and reuses within 1h', () async {
      when(() => remote.search('Morning')).thenAnswer(
        (_) async => DuaSearchResponseModel.fromJson(duaSearchJson()),
      );

      expect(ok(await repo.search('Morning')).single.id, 9);
      expect(storage.hasCached('duas_search_morning'), isTrue);

      expect(ok(await repo.search('MORNING')).single.id, 9);
      verify(() => remote.search(any())).called(1);
    });

    test('stale cache is refetched', () async {
      storage.seedList('duas_search_a', [
        duaJson(id: 1),
      ], age: const Duration(hours: 2));
      when(() => remote.search('a')).thenAnswer(
        (_) async => DuaSearchResponseModel.fromJson(duaSearchJson()),
      );
      expect(ok(await repo.search('a')).single.id, 9);
    });

    test('empty result list is a success with no items', () async {
      when(() => remote.search('zzz')).thenAnswer(
        (_) async => DuaSearchResponseModel.fromJson({
          'query': 'zzz',
          'results_count': 0,
          'results': [],
        }),
      );
      expect(ok(await repo.search('zzz')), isEmpty);
    });

    test(
      'offline: NetworkFailure without cache, stale cache otherwise',
      () async {
        network.connected = false;
        expect(fail(await repo.search('a')), isA<NetworkFailure>());

        storage.seedList('duas_search_a', [
          duaJson(id: 4),
        ], age: const Duration(days: 1));
        expect(ok(await repo.search('a')).single.id, 4);
      },
    );

    test('server error: cache fallback else ServerFailure', () async {
      when(() => remote.search(any())).thenThrow(const ServerException('bad'));
      expect(fail(await repo.search('a')).message, 'bad');

      storage.seedList('duas_search_a', [
        duaJson(id: 4),
      ], age: const Duration(days: 1));
      expect(ok(await repo.search('a')).single.id, 4);
    });

    test('unexpected error -> UnexpectedFailure', () async {
      when(() => remote.search(any())).thenThrow(Exception('?'));
      expect(fail(await repo.search('a')), isA<UnexpectedFailure>());
    });
  });
}
