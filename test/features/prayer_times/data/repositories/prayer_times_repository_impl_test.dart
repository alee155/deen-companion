import 'package:deen_companion/core/error/exceptions.dart';
import 'package:deen_companion/core/error/failures.dart';
import 'package:deen_companion/core/location/location_service.dart';
import 'package:deen_companion/core/location/location_status.dart';
import 'package:deen_companion/core/usecase/usecase.dart';
import 'package:deen_companion/features/prayer_times/data/datasources/prayer_times_remote_datasource.dart';
import 'package:deen_companion/features/prayer_times/data/models/prayer_times_model.dart';
import 'package:deen_companion/features/prayer_times/data/repositories/prayer_times_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../_support/prayer_area_support.dart';

class _MockRemote extends Mock implements PrayerTimesRemoteDataSource {}

PrayerTimesModel _model([int fajrHour = 5]) => PrayerTimesModel(
  fajr: DateTime(2026, 9, 30, fajrHour),
  dhuhr: DateTime(2026, 9, 30, 12),
  asr: DateTime(2026, 9, 30, 15),
  maghrib: DateTime(2026, 9, 30, 18),
  isha: DateTime(2026, 9, 30, 19),
  hijriDate: '18 Rabi 1448 AH',
);

void main() {
  late _MockRemote remote;
  late PaLocation location;
  late PaStorage storage;
  late PaNetwork network;
  late PrayerTimesRepositoryImpl repo;

  setUpAll(() {
    registerFallbackValue(const Coordinates(latitude: 0, longitude: 0));
    initFlavorForTests();
  });

  setUp(() {
    remote = _MockRemote();
    location = PaLocation();
    storage = PaStorage();
    network = PaNetwork();
    repo = PrayerTimesRepositoryImpl(
      remoteDataSource: remote,
      locationService: location,
      cacheStore: storage.cache,
      networkInfo: network,
    );
  });

  void stubTimings(PrayerTimesModel m) => when(
    () => remote.getTimings(
      any(),
      method: any(named: 'method'),
      school: any(named: 'school'),
    ),
  ).thenAnswer((_) async => m);

  Failure? failureOf<T>(Result<T> r) =>
      r.when(success: (_) => null, failure: (f) => f);

  group('fetchAndCachePrayerTimes', () {
    test('success returns entity, passes method/school and caches', () async {
      stubTimings(_model());
      final r = await repo.fetchAndCachePrayerTimes(method: 4, school: 1);
      expect(r, isA<Success>());
      verify(() => remote.getTimings(any(), method: 4, school: 1)).called(1);
      expect(
        repo.getCachedPrayerTimesForLastKnownLocation(),
        _model().toEntity(),
      );
    });

    test('location failure is returned without touching the network', () async {
      location.error = locErr(LocationErrorKind.serviceDisabled);
      network.connected = false;
      final r = await repo.fetchAndCachePrayerTimes(method: 3, school: 0);
      final f = failureOf(r);
      expect(f, isA<LocationFailure>());
      expect((f as LocationFailure).kind, LocationErrorKind.serviceDisabled);
      verifyNever(
        () => remote.getTimings(
          any(),
          method: any(named: 'method'),
          school: any(named: 'school'),
        ),
      );
    });

    test('offline with cache returns the cached times', () async {
      stubTimings(_model(4));
      await repo.fetchAndCachePrayerTimes(method: 3, school: 0);
      network.connected = false;
      final r = await repo.fetchAndCachePrayerTimes(method: 3, school: 0);
      expect((r as Success).data.fajr.hour, 4);
      verify(
        () => remote.getTimings(
          any(),
          method: any(named: 'method'),
          school: any(named: 'school'),
        ),
      ).called(1);
    });

    test('offline without cache is NetworkFailure', () async {
      network.connected = false;
      final r = await repo.fetchAndCachePrayerTimes(method: 3, school: 0);
      expect(failureOf(r), isA<NetworkFailure>());
    });

    test('ServerException -> ServerFailure, nothing cached', () async {
      when(
        () => remote.getTimings(
          any(),
          method: any(named: 'method'),
          school: any(named: 'school'),
        ),
      ).thenThrow(const ServerException('x'));
      final r = await repo.fetchAndCachePrayerTimes(method: 3, school: 0);
      expect(failureOf(r), isA<ServerFailure>());
      expect(repo.getCachedPrayerTimesForLastKnownLocation(), isNull);
    });

    test('NetworkException -> NetworkFailure', () async {
      when(
        () => remote.getTimings(
          any(),
          method: any(named: 'method'),
          school: any(named: 'school'),
        ),
      ).thenThrow(const NetworkException());
      expect(
        failureOf(await repo.fetchAndCachePrayerTimes(method: 3, school: 0)),
        isA<NetworkFailure>(),
      );
    });

    test(
      'unparseable payload (FormatException) -> UnexpectedFailure',
      () async {
        when(
          () => remote.getTimings(
            any(),
            method: any(named: 'method'),
            school: any(named: 'school'),
          ),
        ).thenThrow(const FormatException('-----'));
        expect(
          failureOf(await repo.fetchAndCachePrayerTimes(method: 3, school: 0)),
          isA<UnexpectedFailure>(),
        );
      },
    );

    test('a newer successful fetch overwrites the single cache slot', () async {
      stubTimings(_model(4));
      await repo.fetchAndCachePrayerTimes(method: 3, school: 0);
      stubTimings(_model(6));
      await repo.fetchAndCachePrayerTimes(method: 3, school: 0);
      expect(repo.getCachedPrayerTimesForLastKnownLocation()!.fajr.hour, 6);
    });
  });

  group('getCachedPrayerTimesForLastKnownLocation', () {
    test('null when empty', () {
      expect(repo.getCachedPrayerTimesForLastKnownLocation(), isNull);
    });
  });

  group('fetchMonthCalendar', () {
    void stubMonth(List<PrayerTimesModel> l) => when(
      () => remote.getMonthCalendar(
        any(),
        year: any(named: 'year'),
        month: any(named: 'month'),
        method: any(named: 'method'),
        school: any(named: 'school'),
      ),
    ).thenAnswer((_) async => l);

    test('maps models to entities', () async {
      stubMonth([_model(4), _model(5)]);
      final r = await repo.fetchMonthCalendar(
        year: 2026,
        month: 9,
        method: 3,
        school: 0,
      );
      expect((r as Success).data.map((e) => e.fajr.hour), [4, 5]);
    });

    test('location failure', () async {
      location.error = locErr(LocationErrorKind.permissionDenied);
      final r = await repo.fetchMonthCalendar(
        year: 2026,
        month: 9,
        method: 3,
        school: 0,
      );
      expect(failureOf(r), isA<LocationFailure>());
    });

    test('offline is NetworkFailure (no cache fallback for months)', () async {
      network.connected = false;
      final r = await repo.fetchMonthCalendar(
        year: 2026,
        month: 9,
        method: 3,
        school: 0,
      );
      expect(failureOf(r), isA<NetworkFailure>());
    });

    test('server / network / unexpected errors map to failures', () async {
      for (final entry in <Object, Type>{
        const ServerException(): ServerFailure,
        const NetworkException(): NetworkFailure,
        StateError('x'): UnexpectedFailure,
      }.entries) {
        when(
          () => remote.getMonthCalendar(
            any(),
            year: any(named: 'year'),
            month: any(named: 'month'),
            method: any(named: 'method'),
            school: any(named: 'school'),
          ),
        ).thenThrow(entry.key);
        final f = failureOf(
          await repo.fetchMonthCalendar(
            year: 2026,
            month: 9,
            method: 3,
            school: 0,
          ),
        );
        expect(f.runtimeType, entry.value);
      }
    });
  });
}
