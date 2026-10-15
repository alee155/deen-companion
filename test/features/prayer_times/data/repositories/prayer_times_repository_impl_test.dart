import 'package:deen_companion/core/config/flavor_config.dart';
import 'package:deen_companion/core/error/exceptions.dart';
import 'package:deen_companion/core/error/failures.dart';
import 'package:deen_companion/core/location/location_service.dart';
import 'package:deen_companion/core/usecase/usecase.dart';
import 'package:deen_companion/features/prayer_times/data/datasources/aladhan_fallback_datasource.dart';
import 'package:deen_companion/features/prayer_times/data/datasources/prayer_times_remote_datasource.dart';
import 'package:deen_companion/features/prayer_times/data/models/prayer_times_model.dart';
import 'package:deen_companion/features/prayer_times/data/models/server_prayer_times_models.dart';
import 'package:deen_companion/features/prayer_times/data/repositories/prayer_times_repository_impl.dart';
import 'package:deen_companion/features/prayer_times/domain/entities/prayer_times_bundle.dart';
import 'package:deen_companion/features/prayer_times/domain/prayer_times_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../_support/prayer_area_support.dart';

class _MockRemote extends Mock implements PrayerTimesRemoteDataSource {}

class _MockAladhan extends Mock implements AladhanFallbackDataSource {}

const _coords = Coordinates(latitude: 31.5204, longitude: 74.3587);

/// A server response for [dates] (`2026-10-14` …), Karachi / Hanafi.
Map<String, dynamic> _json(List<String> dates, {List<String>? locked}) {
  Map<String, dynamic> day(String date, int i) {
    final d = DateTime.parse(date);
    String utc(int h, int m) =>
        DateTime.utc(d.year, d.month, d.day, h, m).toIso8601String();
    String local(int h, int m) =>
        '${date}T${h.toString().padLeft(2, '0')}:'
        '${m.toString().padLeft(2, '0')}:00+05:00';
    return {
      'date': date,
      'fajr': DateTime.utc(
        d.year,
        d.month,
        d.day - 1,
        23,
        44 + i,
      ).toIso8601String(),
      'sunrise': utc(1, 5),
      'dhuhr': utc(6, 49),
      'asr': utc(10, 54),
      'maghrib': utc(12, 32),
      'isha': utc(13, 53),
      'local': {
        'fajr': local(4, 44 + i),
        'sunrise': local(6, 5),
        'dhuhr': local(11, 49),
        'asr': local(15, 54),
        'maghrib': local(17, 32),
        'isha': local(18, 53),
      },
      'hijri': null,
    };
  }

  return {
    'location': {
      'latitude': 31.52,
      'longitude': 74.36,
      'timezone': 'Asia/Karachi',
    },
    'method': {'id': 1, 'name': 'Karachi', 'school': 'hanafi', 'schoolId': 1},
    'days': [for (var i = 0; i < dates.length; i++) day(dates[i], i)],
    'lockedDates': ?locked,
  };
}

PrayerTimesBundleModel _model(List<String> dates, {List<String>? locked}) =>
    PrayerTimesBundleModel.fromJson(_json(dates, locked: locked));

void main() {
  late _MockRemote remote;
  late _MockAladhan aladhan;
  late PaStorage storage;
  late PaNetwork network;
  late PrayerTimesRepositoryImpl repo;

  setUpAll(() {
    FlavorConfig(flavor: Flavor.dev, enableLogging: false);
    registerFallbackValue(_coords);
  });

  setUp(() {
    remote = _MockRemote();
    aladhan = _MockAladhan();
    storage = PaStorage();
    network = PaNetwork();
    repo = PrayerTimesRepositoryImpl(
      remote: remote,
      fallback: aladhan,
      cacheStore: storage.cache,
      networkInfo: network,
    );
  });

  When<Future<PrayerTimesBundleModel>> stubGuest() => when(
    () => remote.guestTimes(
      any(),
      method: any(named: 'method'),
      school: any(named: 'school'),
      days: any(named: 'days'),
    ),
  );

  When<Future<PrayerTimesBundleModel>> stubAccountMonth() => when(
    () => remote.accountMonth(
      year: any(named: 'year'),
      month: any(named: 'month'),
    ),
  );

  Failure failureOf<T>(Result<T> r) => (r as Error<T>).failure;

  group('caching', () {
    test('nothing cached before the first fetch', () {
      expect(repo.getCachedBundle(), isNull);
      expect(repo.getCachedToday(DateTime.now()), isNull);
    });

    test('a guest fetch is returned and cached', () async {
      stubGuest().thenAnswer((_) async => _model(['2026-10-14', '2026-10-15']));
      final r = await repo.fetchGuestTimes(_coords);
      final bundle = (r as Success<PrayerTimesBundle>).data;
      expect(bundle.days, hasLength(2));
      expect(repo.getCachedBundle(), bundle);
    });

    test('an account fetch is cached too', () async {
      when(
        () => remote.accountTimes(days: any(named: 'days')),
      ).thenAnswer((_) async => _model(['2026-10-14']));
      await repo.fetchAccountTimes();
      expect(repo.getCachedBundle()!.days.single.date, '2026-10-14');
    });

    test('putLocation caches the days and reports the locked ones', () async {
      when(
        () => remote.putLocation(
          any(),
          method: any(named: 'method'),
          school: any(named: 'school'),
        ),
      ).thenAnswer((_) async => _model(['2026-10-14'], locked: ['2026-10-14']));
      final r = await repo.putLocation(_coords, method: 3, school: 0);
      expect((r as Success<PrayerTimesBundle>).data.lockedDates, [
        '2026-10-14',
      ]);
      expect(repo.getCachedBundle(), isNotNull);
    });

    test('a newer fetch replaces the cache', () async {
      stubGuest().thenAnswer((_) async => _model(['2026-10-14']));
      await repo.fetchGuestTimes(_coords);
      stubGuest().thenAnswer((_) async => _model(['2026-10-20']));
      await repo.fetchGuestTimes(_coords);
      expect(repo.getCachedBundle()!.days.single.date, '2026-10-20');
    });

    test('getCachedToday picks the last day whose Fajr has started', () async {
      stubGuest().thenAnswer(
        (_) async => _model(['2026-10-14', '2026-10-15', '2026-10-16']),
      );
      await repo.fetchGuestTimes(_coords);
      // After 15 Oct's Fajr (23:45Z on the 14th) but before 16 Oct's.
      final today = repo.getCachedToday(DateTime.utc(2026, 10, 15, 12))!;
      expect(today.fajr.toUtc(), DateTime.utc(2026, 10, 14, 23, 45));
    });

    test('before the first Fajr it falls back to the first day', () async {
      stubGuest().thenAnswer((_) async => _model(['2026-10-14', '2026-10-15']));
      await repo.fetchGuestTimes(_coords);
      final today = repo.getCachedToday(DateTime.utc(2026, 10, 1))!;
      expect(today.fajr.toUtc(), DateTime.utc(2026, 10, 13, 23, 44));
    });

    test('an unreadable cache is ignored instead of throwing', () {
      storage.seed('prayer_times_bundle', {'days': 'garbage'});
      expect(repo.getCachedBundle(), isNull);
    });

    test('clearCache drops the bundle and every cached month', () async {
      stubGuest().thenAnswer((_) async => _model(['2026-10-14']));
      await repo.fetchGuestTimes(_coords);
      storage.seed('prayer_times_month_2026_10', _json(['2026-10-14']));
      storage.seed('some_other_feature', {'keep': 1});

      await repo.clearCache();

      expect(storage.hasCached('prayer_times_bundle'), isFalse);
      expect(storage.hasCached('prayer_times_month_2026_10'), isFalse);
      expect(storage.hasCached('some_other_feature'), isTrue);
    });

    test('clearing the account location also clears the cache', () async {
      stubGuest().thenAnswer((_) async => _model(['2026-10-14']));
      await repo.fetchGuestTimes(_coords);
      when(() => remote.clearLocation()).thenAnswer((_) async {});
      expect(await repo.clearAccountLocation(), isA<Success>());
      expect(repo.getCachedBundle(), isNull);
    });

    test('a failed clear keeps the cache', () async {
      stubGuest().thenAnswer((_) async => _model(['2026-10-14']));
      await repo.fetchGuestTimes(_coords);
      when(
        () => remote.clearLocation(),
      ).thenThrow(const ServerException('x', 500));
      expect(await repo.clearAccountLocation(), isA<Error>());
      expect(repo.getCachedBundle(), isNotNull);
    });
  });

  group('months', () {
    test('a month is cached on its own, not as the main bundle', () async {
      stubAccountMonth().thenAnswer(
        (_) async => _model(['2026-10-01', '2026-10-02']),
      );
      final r = await repo.fetchAccountMonth(year: 2026, month: 10);
      expect((r as Success<PrayerTimesBundle>).data.days, hasLength(2));
      expect(storage.hasCached('prayer_times_month_2026_10'), isTrue);
      expect(repo.getCachedBundle(), isNull);
    });

    test('a visited month opens offline from its cache', () async {
      stubAccountMonth().thenAnswer((_) async => _model(['2026-10-01']));
      await repo.fetchAccountMonth(year: 2026, month: 10);

      stubAccountMonth().thenThrow(const NetworkException());
      final r = await repo.fetchAccountMonth(year: 2026, month: 10);
      expect(
        (r as Success<PrayerTimesBundle>).data.days.single.date,
        '2026-10-01',
      );
    });

    test('an unvisited month fails with the real error offline', () async {
      stubAccountMonth().thenThrow(const NetworkException());
      final r = await repo.fetchAccountMonth(year: 2026, month: 12);
      expect(failureOf(r), isA<NetworkFailure>());
    });

    test('a guest month sends the place and caches', () async {
      when(
        () => remote.guestMonth(
          any(),
          year: any(named: 'year'),
          month: any(named: 'month'),
          method: any(named: 'method'),
          school: any(named: 'school'),
        ),
      ).thenAnswer((_) async => _model(['2026-10-01']));
      final r = await repo.fetchGuestMonth(
        _coords,
        year: 2026,
        month: 10,
        method: 3,
        school: 0,
      );
      expect(r, isA<Success>());
      verify(
        () => remote.guestMonth(
          any(),
          year: 2026,
          month: 10,
          method: 3,
          school: 0,
        ),
      ).called(1);
    });
  });

  group('errors', () {
    test('a server code becomes a typed failure', () async {
      when(() => remote.accountTimes(days: any(named: 'days'))).thenThrow(
        const ServerException(
          'Set your location first',
          409,
          'LOCATION_NOT_SET',
        ),
      );
      final f = failureOf(await repo.fetchAccountTimes()) as PrayerTimesFailure;
      expect(f.code, PrayerTimesErrorCode.locationNotSet);
      expect(f.statusCode, 409);
      expect(f.message, 'Set your location first');
    });

    test('503 codes are recognised', () async {
      when(() => remote.accountTimes(days: any(named: 'days'))).thenThrow(
        const ServerException('down', 503, 'PRAYER_PROVIDER_UNAVAILABLE'),
      );
      final f = failureOf(await repo.fetchAccountTimes()) as PrayerTimesFailure;
      expect(f.code, PrayerTimesErrorCode.providerUnavailable);
    });

    test('429 is rate limited even without a code', () async {
      when(
        () => remote.accountTimes(days: any(named: 'days')),
      ).thenThrow(const ServerException('slow down', 429));
      final f = failureOf(await repo.fetchAccountTimes()) as PrayerTimesFailure;
      expect(f.code, PrayerTimesErrorCode.rateLimited);
    });

    test('a connection error is a NetworkFailure', () async {
      when(
        () => remote.accountTimes(days: any(named: 'days')),
      ).thenThrow(const NetworkException());
      expect(failureOf(await repo.fetchAccountTimes()), isA<NetworkFailure>());
    });

    test('offline is reported without calling the server', () async {
      network.connected = false;
      expect(failureOf(await repo.fetchAccountTimes()), isA<NetworkFailure>());
      verifyNever(() => remote.accountTimes(days: any(named: 'days')));
    });

    test('anything unexpected is an UnexpectedFailure', () async {
      when(
        () => remote.accountTimes(days: any(named: 'days')),
      ).thenThrow(StateError('boom'));
      expect(
        failureOf(await repo.fetchAccountTimes()),
        isA<UnexpectedFailure>(),
      );
    });

    test('saved settings, cities and methods use the same guard', () async {
      when(() => remote.getSavedSettings()).thenThrow(const NetworkException());
      when(
        () => remote.searchCities(any()),
      ).thenThrow(const ServerException('x', 503, 'CITY_SEARCH_UNAVAILABLE'));
      when(() => remote.getMethods()).thenAnswer(
        (_) async => const [CalculationMethodOption(id: 1, name: 'Karachi')],
      );
      expect(failureOf(await repo.getSavedSettings()), isA<NetworkFailure>());
      final city =
          failureOf(await repo.searchCities('Lah')) as PrayerTimesFailure;
      expect(city.code, PrayerTimesErrorCode.citySearchUnavailable);
      final methods = await repo.getMethods();
      expect(
        (methods as Success<List<CalculationMethodOption>>).data,
        hasLength(1),
      );
    });
  });

  group('last-resort Aladhan fallback', () {
    PrayerTimesModel aladhanDay(int day) => PrayerTimesModel(
      fajr: DateTime(2026, 10, day, 4, 44),
      dhuhr: DateTime(2026, 10, day, 11, 49),
      asr: DateTime(2026, 10, day, 15, 54),
      maghrib: DateTime(2026, 10, day, 17, 32),
      isha: DateTime(2026, 10, day, 18, 53),
      hijriDate: '3 Jumada 1448 AH',
    );

    When<Future<List<PrayerTimesModel>>> aladhanCall({
      int? method,
      int? school,
    }) => when(
      () => aladhan.getMonthCalendar(
        any(),
        year: any(named: 'year'),
        month: any(named: 'month'),
        method: method ?? any(named: 'method'),
        school: school ?? any(named: 'school'),
      ),
    );

    void stubAladhan() =>
        aladhanCall().thenAnswer((_) async => [aladhanDay(14), aladhanDay(15)]);

    void verifyAladhanNeverCalled() => verifyNever(
      () => aladhan.getMonthCalendar(
        any(),
        year: any(named: 'year'),
        month: any(named: 'month'),
        method: any(named: 'method'),
        school: any(named: 'school'),
      ),
    );

    test('used when the server is unreachable and nothing is cached', () async {
      stubGuest().thenThrow(const NetworkException());
      stubAladhan();
      final r = await repo.fetchGuestTimes(_coords);
      final bundle = (r as Success<PrayerTimesBundle>).data;
      expect(bundle.isUnverified, isTrue);
      expect(bundle.days, hasLength(2));
      expect(bundle.days.first.times.fajr, DateTime(2026, 10, 14, 4, 44));
    });

    test('with the server defaults (1 / 1) when nothing was chosen', () async {
      stubGuest().thenThrow(const NetworkException());
      stubAladhan();
      await repo.fetchGuestTimes(_coords);
      verify(
        () => aladhan.getMonthCalendar(
          any(),
          year: any(named: 'year'),
          month: any(named: 'month'),
          method: 1,
          school: 1,
        ),
      ).called(1);
    });

    test('with the chosen method and school when given', () async {
      stubGuest().thenThrow(const NetworkException());
      stubAladhan();
      await repo.fetchGuestTimes(_coords, method: 3, school: 0);
      verify(
        () => aladhan.getMonthCalendar(
          any(),
          year: any(named: 'year'),
          month: any(named: 'month'),
          method: 3,
          school: 0,
        ),
      ).called(1);
    });

    test('never saved, so it cannot replace a good cache later', () async {
      stubGuest().thenThrow(const NetworkException());
      stubAladhan();
      await repo.fetchGuestTimes(_coords);
      expect(repo.getCachedBundle(), isNull);
    });

    test('a 5xx from the server also triggers it', () async {
      stubGuest().thenThrow(
        const ServerException('down', 503, 'PRAYER_PROVIDER_UNAVAILABLE'),
      );
      stubAladhan();
      final r = await repo.fetchGuestTimes(_coords);
      expect((r as Success<PrayerTimesBundle>).data.isUnverified, isTrue);
    });

    test('NOT used when a cache exists: the cache is kept', () async {
      stubGuest().thenAnswer((_) async => _model(['2026-10-14']));
      await repo.fetchGuestTimes(_coords);
      stubGuest().thenThrow(const NetworkException());

      final r = await repo.fetchGuestTimes(_coords);

      expect(r, isA<Error>());
      verifyAladhanNeverCalled();
      expect(repo.getCachedBundle()!.days.single.date, '2026-10-14');
    });

    test('NOT used for a request error such as a bad method (400)', () async {
      stubGuest().thenThrow(const ServerException('bad', 400));
      final r = await repo.fetchGuestTimes(_coords, method: 6);
      expect(r, isA<Error>());
      verifyAladhanNeverCalled();
    });

    test('when Aladhan fails too, the original error is returned', () async {
      stubGuest().thenThrow(const NetworkException());
      aladhanCall().thenThrow(const ServerException('aladhan down'));
      expect(
        failureOf(await repo.fetchGuestTimes(_coords)),
        isA<NetworkFailure>(),
      );
    });

    test('offline with nothing cached tries Aladhan, then gives up', () async {
      network.connected = false;
      aladhanCall().thenThrow(const NetworkException());
      expect(
        failureOf(await repo.fetchGuestTimes(_coords)),
        isA<NetworkFailure>(),
      );
    });
  });
}
