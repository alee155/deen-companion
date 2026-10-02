import 'package:deen_companion/core/error/exceptions.dart';
import 'package:deen_companion/core/error/failures.dart';
import 'package:deen_companion/core/usecase/usecase.dart';
import 'package:deen_companion/features/asma_ul_husna/data/datasources/asma_ul_husna_remote_datasource.dart';
import 'package:deen_companion/features/asma_ul_husna/data/models/asma_daily_model.dart';
import 'package:deen_companion/features/asma_ul_husna/data/models/asma_name_model.dart';
import 'package:deen_companion/features/asma_ul_husna/data/repositories/asma_ul_husna_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../_support/cache_test_support.dart';
import '../../../_support/names_fixtures.dart';

class MockRemote extends Mock implements AsmaUlHusnaRemoteDataSource {}

T ok<T>(Result<T> r) => (r as Success<T>).data;
Failure fail<T>(Result<T> r) => (r as Error<T>).failure;

List<AsmaNameModel> models(int n) => [
  for (var i = 1; i <= n; i++) AsmaNameModel.fromJson(asmaNameJson(n: i)),
];

void main() {
  late MockRemote remote;
  late InMemoryStorage storage;
  late FakeNetworkInfo network;
  late AsmaUlHusnaRepositoryImpl repo;

  setUp(() {
    remote = MockRemote();
    storage = InMemoryStorage();
    network = FakeNetworkInfo();
    repo = AsmaUlHusnaRepositoryImpl(
      remoteDataSource: remote,
      cacheStore: storeFor(storage),
      networkInfo: network,
    );
  });

  group('all names', () {
    test(
      'fetch caches in order and round-trips via getCachedAllNames',
      () async {
        when(() => remote.getAllNames()).thenAnswer((_) async => models(3));
        expect(repo.getCachedAllNames(), isNull);

        expect(ok(await repo.fetchAndCacheAllNames()), hasLength(3));
        expect(repo.getCachedAllNames()!.map((n) => n.number), [1, 2, 3]);
      },
    );

    test('90 day TTL and forceRefresh', () async {
      storage.seedList('asma_all_names', [
        asmaNameJson(),
      ], age: const Duration(days: 89));
      expect(ok(await repo.fetchAndCacheAllNames()), hasLength(1));
      verifyZeroInteractions(remote);

      when(() => remote.getAllNames()).thenAnswer((_) async => models(2));
      expect(
        ok(await repo.fetchAndCacheAllNames(forceRefresh: true)),
        hasLength(2),
      );

      storage.seedList('asma_all_names', [
        asmaNameJson(),
      ], age: const Duration(days: 91));
      expect(ok(await repo.fetchAndCacheAllNames()), hasLength(2));
    });

    test('offline / server / unexpected', () async {
      network.connected = false;
      expect(fail(await repo.fetchAndCacheAllNames()), isA<NetworkFailure>());
      storage.seedList('asma_all_names', [
        asmaNameJson(),
      ], age: const Duration(days: 200));
      expect(ok(await repo.fetchAndCacheAllNames()), hasLength(1));

      network.connected = true;
      when(() => remote.getAllNames()).thenThrow(const ServerException('s'));
      expect(ok(await repo.fetchAndCacheAllNames()), hasLength(1));

      storage.boxes.clear();
      expect(fail(await repo.fetchAndCacheAllNames()).message, 's');
      when(() => remote.getAllNames()).thenThrow(StateError('x'));
      expect(
        fail(await repo.fetchAndCacheAllNames()),
        isA<UnexpectedFailure>(),
      );
    });
  });

  group('daily', () {
    test('caches per day number', () async {
      when(() => remote.getDailyNames(any())).thenAnswer(
        (i) async => AsmaDailyModel.fromJson(
          asmaDailyJson(day: i.positionalArguments.first as int),
        ),
      );

      expect(ok(await repo.fetchDailyNames(1)).dayNumber, 1);
      expect(ok(await repo.fetchDailyNames(2)).dayNumber, 2);
      expect(storage.hasCached('asma_daily_1'), isTrue);
      expect(storage.hasCached('asma_daily_2'), isTrue);

      await repo.fetchDailyNames(1); // served from cache
      verify(() => remote.getDailyNames(1)).called(1);
    });

    test('forceRefresh refetches', () async {
      storage.seed('asma_daily_1', asmaDailyJson());
      when(
        () => remote.getDailyNames(1),
      ).thenAnswer((_) async => AsmaDailyModel.fromJson(asmaDailyJson()));
      await repo.fetchDailyNames(1, forceRefresh: true);
      verify(() => remote.getDailyNames(1)).called(1);
    });

    test('offline / server / unexpected', () async {
      network.connected = false;
      expect(fail(await repo.fetchDailyNames(1)), isA<NetworkFailure>());
      storage.seed(
        'asma_daily_1',
        asmaDailyJson(),
        age: const Duration(days: 200),
      );
      expect(ok(await repo.fetchDailyNames(1)).names, hasLength(2));

      network.connected = true;
      when(() => remote.getDailyNames(1)).thenThrow(const ServerException('s'));
      expect(ok(await repo.fetchDailyNames(1)).names, hasLength(2));

      storage.boxes.clear();
      expect(fail(await repo.fetchDailyNames(1)).message, 's');
      when(() => remote.getDailyNames(1)).thenThrow(StateError('x'));
      expect(fail(await repo.fetchDailyNames(1)), isA<UnexpectedFailure>());
    });
  });

  group('search', () {
    test('caches case-insensitively for 1h', () async {
      when(() => remote.search('Mercy')).thenAnswer((_) async => models(1));
      ok(await repo.search('Mercy'));
      ok(await repo.search('MERCY'));
      verify(() => remote.search(any())).called(1);
      expect(storage.hasCached('asma_search_mercy'), isTrue);
    });

    test('stale cache refetches', () async {
      storage.seedList('asma_search_a', [
        asmaNameJson(),
      ], age: const Duration(hours: 2));
      when(() => remote.search('a')).thenAnswer((_) async => models(3));
      expect(ok(await repo.search('a')), hasLength(3));
    });

    test('offline / server / unexpected', () async {
      network.connected = false;
      expect(fail(await repo.search('a')), isA<NetworkFailure>());
      storage.seedList('asma_search_a', [
        asmaNameJson(),
      ], age: const Duration(days: 1));
      expect(ok(await repo.search('a')), hasLength(1));

      network.connected = true;
      when(() => remote.search(any())).thenThrow(const ServerException('s'));
      expect(ok(await repo.search('a')), hasLength(1));

      storage.boxes.clear();
      expect(fail(await repo.search('a')).message, 's');
      when(() => remote.search(any())).thenThrow(StateError('x'));
      expect(fail(await repo.search('a')), isA<UnexpectedFailure>());
    });

    test('no matches is a successful empty list', () async {
      when(() => remote.search('zzz')).thenAnswer((_) async => []);
      expect(ok(await repo.search('zzz')), isEmpty);
    });
  });
}
