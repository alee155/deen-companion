import 'package:deen_companion/core/error/exceptions.dart';
import 'package:deen_companion/core/error/failures.dart';
import 'package:deen_companion/core/usecase/usecase.dart';
import 'package:deen_companion/features/islamic_names/data/datasources/islamic_names_remote_datasource.dart';
import 'package:deen_companion/features/islamic_names/data/models/islamic_name_model.dart';
import 'package:deen_companion/features/islamic_names/data/repositories/islamic_names_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../_support/cache_test_support.dart';
import '../../../_support/names_fixtures.dart';

class MockRemote extends Mock implements IslamicNamesRemoteDataSource {}

T ok<T>(Result<T> r) => (r as Success<T>).data;
Failure fail<T>(Result<T> r) => (r as Error<T>).failure;

void main() {
  late MockRemote remote;
  late InMemoryStorage storage;
  late FakeNetworkInfo network;
  late IslamicNamesRepositoryImpl repo;

  List<IslamicNameModel> models() => [
    IslamicNameModel.fromJson(islamicNameJson()),
    IslamicNameModel.fromJson(islamicNameJson(id: 2, name: 'Musa', root: null)),
  ];

  setUp(() {
    remote = MockRemote();
    storage = InMemoryStorage();
    network = FakeNetworkInfo();
    repo = IslamicNamesRepositoryImpl(
      remoteDataSource: remote,
      cacheStore: storeFor(storage),
      networkInfo: network,
    );
  });

  test('getCachedNames is null on empty cache', () {
    expect(repo.getCachedNames(), isNull);
  });

  test('fetch caches names, preserving null roots through the cache', () async {
    when(() => remote.getAllNames()).thenAnswer((_) async => models());

    expect(ok(await repo.fetchAndCacheNames()), hasLength(2));

    final cached = repo.getCachedNames()!;
    expect(cached.map((n) => n.name), ['Aisha', 'Musa']);
    expect(cached.last.root, isNull);
  });

  test('fresh cache: no network; 90 day boundary; forceRefresh', () async {
    storage.seedList('islamic_names_all', [
      islamicNameJson(),
    ], age: const Duration(days: 89));
    expect(ok(await repo.fetchAndCacheNames()), hasLength(1));
    verifyZeroInteractions(remote);

    when(() => remote.getAllNames()).thenAnswer((_) async => models());
    expect(ok(await repo.fetchAndCacheNames(forceRefresh: true)), hasLength(2));

    storage.seedList('islamic_names_all', [
      islamicNameJson(),
    ], age: const Duration(days: 91));
    expect(ok(await repo.fetchAndCacheNames()), hasLength(2));
    verify(() => remote.getAllNames()).called(2);
  });

  test(
    'offline: NetworkFailure without cache, stale cache otherwise',
    () async {
      network.connected = false;
      expect(fail(await repo.fetchAndCacheNames()), isA<NetworkFailure>());
      verifyZeroInteractions(remote);

      storage.seedList('islamic_names_all', [
        islamicNameJson(),
      ], age: const Duration(days: 300));
      expect(ok(await repo.fetchAndCacheNames()), hasLength(1));
    },
  );

  test(
    'server error: cache fallback else ServerFailure with message',
    () async {
      when(() => remote.getAllNames()).thenThrow(const ServerException('bad'));
      final f = fail(await repo.fetchAndCacheNames());
      expect(f, isA<ServerFailure>());
      expect(f.message, 'bad');

      storage.seedList('islamic_names_all', [
        islamicNameJson(),
      ], age: const Duration(days: 300));
      expect(ok(await repo.fetchAndCacheNames()), hasLength(1));
    },
  );

  test('unexpected error -> UnexpectedFailure', () async {
    when(() => remote.getAllNames()).thenThrow(StateError('x'));
    expect(fail(await repo.fetchAndCacheNames()), isA<UnexpectedFailure>());
  });
}
