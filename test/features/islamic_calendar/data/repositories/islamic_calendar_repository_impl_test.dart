import 'package:deen_companion/core/error/exceptions.dart';
import 'package:deen_companion/core/error/failures.dart';
import 'package:deen_companion/core/usecase/usecase.dart';
import 'package:deen_companion/features/islamic_calendar/data/datasources/islamic_calendar_remote_datasource.dart';
import 'package:deen_companion/features/islamic_calendar/data/models/hijri_conversion_model.dart';
import 'package:deen_companion/features/islamic_calendar/data/models/islamic_events_bundle_model.dart';
import 'package:deen_companion/features/islamic_calendar/data/models/islamic_month_model.dart';
import 'package:deen_companion/features/islamic_calendar/data/repositories/islamic_calendar_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../_support/prayer_area_support.dart';
import '../../_fixtures.dart';

class _MockRemote extends Mock implements IslamicCalendarRemoteDataSource {}

HijriConversionModel _conv({int year = 1448}) => HijriConversionModel.fromJson({
  'gregorian': gregorianJson(),
  'hijri': hijriJson(year: year),
});

void main() {
  late _MockRemote remote;
  late PaStorage storage;
  late PaNetwork network;
  late IslamicCalendarRepositoryImpl repo;

  setUpAll(initFlavorForTests);
  setUp(() {
    remote = _MockRemote();
    storage = PaStorage();
    network = PaNetwork();
    repo = IslamicCalendarRepositoryImpl(
      remoteDataSource: remote,
      cacheStore: storage.cache,
      networkInfo: network,
    );
  });

  Failure failure<T>(Result<T> r) => (r as Error<T>).failure;
  T data<T>(Result<T> r) => (r as Success<T>).data;

  group('fetchTodayHijri', () {
    test('fetches, caches, and then serves the same-day cache without network', () async {
      when(() => remote.getTodayHijri()).thenAnswer((_) async => _conv());
      expect(data(await repo.fetchTodayHijri()).hijri.year, 1448);
      expect(repo.getCachedTodayHijri(), isNotNull);
      await repo.fetchTodayHijri();
      verify(() => remote.getTodayHijri()).called(1);
    });

    test('forceRefresh ignores a same-day cache', () async {
      when(() => remote.getTodayHijri()).thenAnswer((_) async => _conv());
      await repo.fetchTodayHijri();
      await repo.fetchTodayHijri(forceRefresh: true);
      verify(() => remote.getTodayHijri()).called(2);
    });

    test('cache written yesterday is not treated as today', () async {
      storage.seed('islamic_today_hijri', _conv(year: 1447).toJson(),
          age: const Duration(days: 1));
      expect(repo.getCachedTodayHijri(), isNull);
      when(() => remote.getTodayHijri()).thenAnswer((_) async => _conv());
      expect(data(await repo.fetchTodayHijri()).hijri.year, 1448);
    });

    test('offline: yesterday\'s cache is used as a stale fallback', () async {
      storage.seed('islamic_today_hijri', _conv(year: 1447).toJson(),
          age: const Duration(days: 2));
      network.connected = false;
      expect(data(await repo.fetchTodayHijri()).hijri.year, 1447);
      verifyNever(() => remote.getTodayHijri());
    });

    test('offline with nothing cached -> NetworkFailure', () async {
      network.connected = false;
      expect(failure(await repo.fetchTodayHijri()), isA<NetworkFailure>());
    });

    test('ServerException: stale cache if any, else ServerFailure with message', () async {
      when(() => remote.getTodayHijri()).thenThrow(const ServerException('503'));
      final f = failure(await repo.fetchTodayHijri());
      expect(f, isA<ServerFailure>());
      expect(f.message, '503');
      storage.seed('islamic_today_hijri', _conv(year: 1447).toJson(),
          age: const Duration(days: 3));
      expect(data(await repo.fetchTodayHijri()).hijri.year, 1447);
    });

    test('malformed payload -> UnexpectedFailure', () async {
      when(() => remote.getTodayHijri()).thenThrow(TypeError());
      expect(failure(await repo.fetchTodayHijri()), isA<UnexpectedFailure>());
    });
  });

  group('conversions', () {
    test('g2h caches per exact date (different day -> new request)', () async {
      when(() => remote.getHijriDate(any(), any(), any())).thenAnswer((_) async => _conv());
      await repo.convertGregorianToHijri(2026, 6, 16);
      await repo.convertGregorianToHijri(2026, 6, 16);
      await repo.convertGregorianToHijri(2026, 6, 17);
      verify(() => remote.getHijriDate(2026, 6, 16)).called(1);
      verify(() => remote.getHijriDate(2026, 6, 17)).called(1);
    });

    test('g2h and h2g caches do not collide for the same numbers', () async {
      when(() => remote.getHijriDate(any(), any(), any())).thenAnswer((_) async => _conv(year: 1448));
      when(() => remote.getGregorianDate(any(), any(), any())).thenAnswer((_) async => _conv(year: 1111));
      final a = data(await repo.convertGregorianToHijri(2026, 1, 1));
      final b = data(await repo.convertHijriToGregorian(2026, 1, 1));
      expect(a.hijri.year, 1448);
      expect(b.hijri.year, 1111);
    });

    test('conversion cache expires after 365 days', () async {
      storage.seed('islamic_g2h_2026_6_16', _conv(year: 1111).toJson(),
          age: const Duration(days: 364));
      when(() => remote.getHijriDate(any(), any(), any())).thenAnswer((_) async => _conv());
      expect(data(await repo.convertGregorianToHijri(2026, 6, 16)).hijri.year, 1111);
      storage.seed('islamic_g2h_2026_6_16', _conv(year: 1111).toJson(),
          age: const Duration(days: 366));
      expect(data(await repo.convertGregorianToHijri(2026, 6, 16)).hijri.year, 1448);
    });

    test('forceRefresh bypasses cache', () async {
      storage.seed('islamic_h2g_1448_1_1', _conv(year: 1111).toJson());
      when(() => remote.getGregorianDate(any(), any(), any())).thenAnswer((_) async => _conv());
      expect(
        data(await repo.convertHijriToGregorian(1448, 1, 1, forceRefresh: true)).hijri.year,
        1448,
      );
    });

    test('offline: expired cache still served; none -> NetworkFailure', () async {
      network.connected = false;
      expect(failure(await repo.convertGregorianToHijri(2026, 6, 16)), isA<NetworkFailure>());
      storage.seed('islamic_g2h_2026_6_16', _conv(year: 1111).toJson(),
          age: const Duration(days: 900));
      expect(data(await repo.convertGregorianToHijri(2026, 6, 16)).hijri.year, 1111);
    });

    test('server error falls back to cache, else ServerFailure', () async {
      when(() => remote.getGregorianDate(any(), any(), any())).thenThrow(const ServerException());
      expect(failure(await repo.convertHijriToGregorian(1448, 1, 1)), isA<ServerFailure>());
      storage.seed('islamic_h2g_1448_1_1', _conv(year: 1111).toJson(), age: const Duration(days: 900));
      expect(data(await repo.convertHijriToGregorian(1448, 1, 1)).hijri.year, 1111);
    });

    test('unexpected exceptions map to UnexpectedFailure', () async {
      when(() => remote.getHijriDate(any(), any(), any())).thenThrow(StateError('x'));
      expect(failure(await repo.convertGregorianToHijri(2026, 1, 1)), isA<UnexpectedFailure>());
      when(() => remote.getGregorianDate(any(), any(), any())).thenThrow(StateError('x'));
      expect(failure(await repo.convertHijriToGregorian(1448, 1, 1)), isA<UnexpectedFailure>());
    });
  });

  group('months', () {
    List<IslamicMonthModel> months() =>
        [for (var i = 1; i <= 12; i++) IslamicMonthModel.fromJson(monthJson(i))];

    test('fetch caches the list and getCachedMonths reads it back', () async {
      when(() => remote.getIslamicMonths()).thenAnswer((_) async => months());
      expect(repo.getCachedMonths(), isNull);
      expect(data(await repo.fetchAndCacheMonths()), hasLength(12));
      final cached = repo.getCachedMonths()!;
      expect(cached, hasLength(12));
      expect(cached[8].number, 9);
    });

    test('fresh (<90d) cache is served without network; older refetches', () async {
      when(() => remote.getIslamicMonths()).thenAnswer((_) async => months());
      storage.seed('islamic_months', {'list': [monthJson(1)]}, age: const Duration(days: 89));
      expect(data(await repo.fetchAndCacheMonths()), hasLength(1));
      verifyNever(() => remote.getIslamicMonths());
      storage.seed('islamic_months', {'list': [monthJson(1)]}, age: const Duration(days: 91));
      expect(data(await repo.fetchAndCacheMonths()), hasLength(12));
    });

    test('offline / server error fall back to cache', () async {
      storage.seed('islamic_months', {'list': [monthJson(1)]}, age: const Duration(days: 200));
      network.connected = false;
      expect(data(await repo.fetchAndCacheMonths()), hasLength(1));
      network.connected = true;
      when(() => remote.getIslamicMonths()).thenThrow(const ServerException());
      expect(data(await repo.fetchAndCacheMonths()), hasLength(1));
    });

    test('failure kinds without cache', () async {
      network.connected = false;
      expect(failure(await repo.fetchAndCacheMonths()), isA<NetworkFailure>());
      network.connected = true;
      when(() => remote.getIslamicMonths()).thenThrow(const ServerException('x'));
      expect(failure(await repo.fetchAndCacheMonths()), isA<ServerFailure>());
      when(() => remote.getIslamicMonths()).thenThrow(StateError('x'));
      expect(failure(await repo.fetchAndCacheMonths()), isA<UnexpectedFailure>());
    });
  });

  group('events', () {
    IslamicEventsBundleModel bundle() => IslamicEventsBundleModel.fromJson(eventsBundleJson());

    test('fetch maps to entity and caches', () async {
      when(() => remote.getIslamicEvents()).thenAnswer((_) async => bundle());
      final b = data(await repo.fetchAndCacheEvents());
      expect(b.nextEvent.name, 'Ashura');
      expect(b.events, hasLength(2));
      expect(repo.getCachedEvents()!.currentDate.hijri.year, 1448);
    });

    test('12h TTL: 11h old served from cache, 13h old refetched', () async {
      when(() => remote.getIslamicEvents()).thenAnswer((_) async => bundle());
      storage.seed('islamic_events', eventsBundleJson(), age: const Duration(hours: 11));
      await repo.fetchAndCacheEvents();
      verifyNever(() => remote.getIslamicEvents());
      storage.seed('islamic_events', eventsBundleJson(), age: const Duration(hours: 13));
      await repo.fetchAndCacheEvents();
      verify(() => remote.getIslamicEvents()).called(1);
    });

    test('offline and server-error fallbacks plus failure kinds', () async {
      network.connected = false;
      expect(failure(await repo.fetchAndCacheEvents()), isA<NetworkFailure>());
      storage.seed('islamic_events', eventsBundleJson(), age: const Duration(days: 5));
      expect(data(await repo.fetchAndCacheEvents()).events, hasLength(2));
      network.connected = true;
      when(() => remote.getIslamicEvents()).thenThrow(const ServerException());
      expect(data(await repo.fetchAndCacheEvents()).events, hasLength(2));
      storage.boxes.clear();
      expect(failure(await repo.fetchAndCacheEvents()), isA<ServerFailure>());
      when(() => remote.getIslamicEvents()).thenThrow(StateError('x'));
      expect(failure(await repo.fetchAndCacheEvents()), isA<UnexpectedFailure>());
    });
  });
}
