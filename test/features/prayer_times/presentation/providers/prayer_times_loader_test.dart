import 'dart:async';

import 'package:deen_companion/core/di/providers.dart';
import 'package:deen_companion/core/error/failures.dart';
import 'package:deen_companion/core/location/location_service.dart';
import 'package:deen_companion/core/location/location_status.dart';
import 'package:deen_companion/core/usecase/usecase.dart';
import 'package:deen_companion/features/auth/domain/entities/auth_session.dart';
import 'package:deen_companion/features/auth/presentation/providers/auth_session_provider.dart';
import 'package:deen_companion/features/prayer_times/domain/entities/prayer_calculation_settings.dart';
import 'package:deen_companion/features/prayer_times/domain/entities/prayer_times_bundle.dart';
import 'package:deen_companion/features/prayer_times/presentation/providers/manual_city_provider.dart';
import 'package:deen_companion/features/prayer_times/presentation/providers/prayer_calculation_settings_provider.dart';
import 'package:deen_companion/features/prayer_times/presentation/providers/prayer_times_loader.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../_support/prayer_area_support.dart';
import '../../../prayer_logs/presentation/_prayer_log_test_support.dart';

const _lahoreCity = PrayerCity(
  name: 'Lahore',
  region: 'Punjab',
  country: 'Pakistan',
  countryCode: 'PK',
  latitude: 31.558,
  longitude: 74.3507,
  timezone: 'Asia/Karachi',
);

const _dubaiCity = PrayerCity(
  name: 'Dubai',
  region: 'Dubai',
  country: 'United Arab Emirates',
  countryCode: 'AE',
  latitude: 25.2,
  longitude: 55.27,
  timezone: 'Asia/Dubai',
);

void main() {
  late FakePrayerRepo repo;
  late PaStorage storage;
  late PaLocation location;

  setUpAll(initFlavorForTests);

  setUp(() {
    repo = FakePrayerRepo();
    storage = PaStorage();
    location = PaLocation()
      ..coordinates = const Coordinates(latitude: 31.5204, longitude: 74.3587);
    final b = bundleOf([pt(14)]);
    repo
      ..guestResult = Success(b)
      ..putResult = Success(b)
      ..accountResult = Success(b);
  });

  ProviderContainer make({
    bool signedIn = false,
    String? quick = 'PK',
    String? country,
  }) {
    final c = ProviderContainer(
      overrides: [
        localStorageServiceProvider.overrideWithValue(storage),
        authSessionProvider.overrideWith(
          signedIn ? SignedIn.new : SignedOut.new,
        ),
        locationServiceProvider.overrideWithValue(location),
        prayerTimesRepositoryProvider.overrideWithValue(repo),
        quickCountryProvider.overrideWithValue(quick),
        deviceCountryCodeProvider.overrideWith((ref) async => country),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  PrayerTimesLoader loader(ProviderContainer c) =>
      c.read(prayerTimesLoaderProvider);

  group('place', () {
    test('uses the device location and the timezone-derived country', () async {
      final place = await loader(make()).resolvePlace();
      expect(place.coordinates.latitude, 31.5204);
      expect(place.countryCode, 'PK');
      expect(place.city, isNull);
    });

    test('a picked city wins over the device location', () async {
      final c = make();
      await c.read(manualCityProvider.notifier).select(_dubaiCity);
      final place = await loader(c).resolvePlace();
      expect(place.coordinates.latitude, 25.2);
      expect(place.countryCode, 'AE');
      expect(place.city, _dubaiCity);
      expect(location.calls, 0, reason: 'GPS is not asked while a city is set');
    });

    test('clearing the city goes back to the device location', () async {
      final c = make();
      await c.read(manualCityProvider.notifier).select(_dubaiCity);
      await c.read(manualCityProvider.notifier).clear();
      final place = await loader(c).resolvePlace();
      expect(place.coordinates.latitude, 31.5204);
    });

    test('a location problem surfaces as a LocationFailure', () async {
      location.error = locErr(LocationErrorKind.permissionDenied);
      await expectLater(
        loader(make()).resolvePlace(),
        throwsA(
          isA<LocationFailure>().having(
            (f) => f.kind,
            'kind',
            LocationErrorKind.permissionDenied,
          ),
        ),
      );
    });

    test('country falls back to the device lookup, and to unknown', () async {
      final known = await loader(
        make(quick: null, country: 'AE'),
      ).resolvePlace();
      expect(known.countryCode, 'AE');
      final unknown = await loader(make(quick: null)).resolvePlace();
      expect(unknown.countryCode, isNull);
    });

    test('a city picked as a guest survives a restart', () async {
      final c1 = make();
      await c1.read(manualCityProvider.notifier).select(_lahoreCity);
      final c2 = make();
      expect(c2.read(manualCityProvider), _lahoreCity);
    });

    test('a damaged saved city is treated as none', () async {
      storage.boxes['settings_box'] = {
        'prayer_manual_city': {'name': 'x'}, // no coordinates
      };
      expect(make().read(manualCityProvider), isNull);
    });
  });

  group('refresh', () {
    test('a location failure is returned, nothing is requested', () async {
      location.error = locErr(LocationErrorKind.serviceDisabled);
      final r = await loader(make()).refresh();
      expect((r as Error).failure, isA<LocationFailure>());
      expect(repo.calls, isEmpty);
    });

    test('guest: asks the guest endpoint with the place', () async {
      final r = await loader(make()).refresh();
      expect(r, isA<Success>());
      expect(repo.calls, ['guestTimes']);
      expect(repo.lastCoordinates!.latitude, 31.5204);
    });

    test('signed in: goes through the account flow', () async {
      await loader(make(signedIn: true)).refresh();
      expect(repo.calls, ['getSaved', 'put', 'accountTimes']);
    });

    test('adopts the server\'s method and school', () async {
      final c = make(quick: null);
      await loader(c).refresh();
      final s = c.read(prayerCalculationSettingsProvider);
      expect(s.method, PrayerCalculationMethod.karachi);
      expect(s.school, AsrSchool.hanafi);
      expect(storage.boxes['settings_box']!['prayer_calculation_method'], 1);
    });

    test('sends what the user chose, and marks it synced', () async {
      final c = make();
      await c
          .read(prayerCalculationSettingsProvider.notifier)
          .setMethod(PrayerCalculationMethod.egyptian);
      expect(
        c.read(prayerCalculationSettingsProvider.notifier).choice.changedByUser,
        isTrue,
      );

      await loader(c).refresh();

      expect(repo.lastSent!.method, 5);
      expect(
        c.read(prayerCalculationSettingsProvider.notifier).choice.changedByUser,
        isFalse,
      );
    });

    test('raises the locked-days notice only after a user change', () async {
      repo.savedResult = const Success(
        SavedPrayerSettings(
          location: PrayerLocation(
            latitude: 31.52,
            longitude: 74.36,
            timezone: 'Asia/Karachi',
          ),
          method: CalculationMethodInfo(
            id: 1,
            name: 'Karachi',
            school: 'hanafi',
            schoolId: 1,
          ),
        ),
      );
      repo.putResult = Success(bundleOf([pt(14)], lockedDates: ['2026-10-14']));
      final c = make(signedIn: true);

      // A routine refresh: nothing to announce.
      await loader(c).refresh();
      expect(c.read(lockedDatesNoticeProvider), isEmpty);

      await c
          .read(prayerCalculationSettingsProvider.notifier)
          .setSchool(AsrSchool.shafi);
      await loader(c).refresh();
      expect(c.read(lockedDatesNoticeProvider), ['2026-10-14']);
    });

    test('a failure leaves the user\'s pending change pending', () async {
      repo.guestResult = const Error(NetworkFailure());
      final c = make();
      await c
          .read(prayerCalculationSettingsProvider.notifier)
          .setMethod(PrayerCalculationMethod.egyptian);
      await loader(c).refresh();
      expect(
        c.read(prayerCalculationSettingsProvider.notifier).choice.changedByUser,
        isTrue,
        reason: 'it will be sent on the next successful refresh',
      );
    });

    test(
      'unverified fallback times do not change the saved settings',
      () async {
        repo.guestResult = Success(bundleOf([pt(14)], unverified: true));
        final c = make();
        await loader(c).refresh();
        expect(
          storage.boxes['settings_box']?['prayer_calculation_method'],
          isNull,
        );
      },
    );

    test('simultaneous refreshes share one request', () async {
      final gate = Completer<void>();
      final slow = _SlowRepo(repo, gate.future);
      final c = ProviderContainer(
        overrides: [
          localStorageServiceProvider.overrideWithValue(storage),
          authSessionProvider.overrideWith(SignedOut.new),
          locationServiceProvider.overrideWithValue(location),
          prayerTimesRepositoryProvider.overrideWithValue(slow),
          quickCountryProvider.overrideWithValue('PK'),
        ],
      );
      addTearDown(c.dispose);
      final l = c.read(prayerTimesLoaderProvider);

      final a = l.refresh();
      final b = l.refresh();
      gate.complete();
      await Future.wait([a, b]);

      expect(slow.guestCalls, 1);
    });

    test('force starts a new refresh even while one is running', () async {
      final gate = Completer<void>();
      final slow = _SlowRepo(repo, gate.future);
      final c = ProviderContainer(
        overrides: [
          localStorageServiceProvider.overrideWithValue(storage),
          authSessionProvider.overrideWith(SignedOut.new),
          locationServiceProvider.overrideWithValue(location),
          prayerTimesRepositoryProvider.overrideWithValue(slow),
          quickCountryProvider.overrideWithValue('PK'),
        ],
      );
      addTearDown(c.dispose);
      final l = c.read(prayerTimesLoaderProvider);

      final a = l.refresh();
      final b = l.refresh(force: true);
      gate.complete();
      await Future.wait([a, b]);

      expect(slow.guestCalls, 2);
    });
  });

  group(
    'times-updated signal (re-arms reminders, DND, daily notification)',
    () {
      int signal(ProviderContainer c) => c.read(prayerTimesUpdatedProvider);

      test('the first times ever fetched raise it', () async {
        final c = make();
        await loader(c).refresh();
        expect(signal(c), 1);
      });

      test('identical times (same as the cache) do not', () async {
        repo.bundle = bundleOf([pt(14)]);
        repo.guestResult = Success(bundleOf([pt(14)]));
        final c = make();
        await loader(c).refresh();
        expect(signal(c), 0);
      });

      test('different times raise it', () async {
        repo.bundle = bundleOf([pt(14)]);
        repo.guestResult = Success(bundleOf([pt(14, fajr: 4)]));
        final c = make();
        await loader(c).refresh();
        expect(signal(c), 1);
      });

      test('a different number of days raises it', () async {
        repo.bundle = bundleOf([pt(14)]);
        repo.guestResult = Success(bundleOf([pt(14), pt(15)]));
        final c = make();
        await loader(c).refresh();
        expect(signal(c), 1);
      });

      test('only the locked-days list changing does not', () async {
        repo.bundle = bundleOf([pt(14)]);
        repo.guestResult = Success(
          bundleOf([pt(14)], lockedDates: ['2026-09-14']),
        );
        final c = make();
        await loader(c).refresh();
        expect(signal(c), 0);
      });

      test('a failed refresh does not', () async {
        repo.guestResult = const Error(NetworkFailure());
        final c = make();
        await loader(c).refresh();
        expect(signal(c), 0);
      });

      test('a location problem does not', () async {
        location.error = locErr(LocationErrorKind.serviceDisabled);
        final c = make();
        await loader(c).refresh();
        expect(signal(c), 0);
      });

      test('unverified fallback times that differ raise it', () async {
        repo.guestResult = Success(bundleOf([pt(14)], unverified: true));
        final c = make();
        await loader(c).refresh();
        expect(signal(c), 1);
      });

      test('two joined refreshes raise it once', () async {
        final c = make();
        final l = loader(c);
        await Future.wait([l.refresh(), l.refresh()]);
        expect(signal(c), 1);
      });
    },
  );

  group('sign-out', () {
    test('drops the cached days, but keeps the picked city', () async {
      final c = ProviderContainer(
        overrides: [
          localStorageServiceProvider.overrideWithValue(storage),
          authSessionProvider.overrideWith(_SwitchSession.new),
          locationServiceProvider.overrideWithValue(location),
          prayerTimesRepositoryProvider.overrideWithValue(repo),
          quickCountryProvider.overrideWithValue('PK'),
          deviceCountryCodeProvider.overrideWith((ref) async => null),
        ],
      );
      addTearDown(c.dispose);
      c.read(prayerTimesLoaderProvider);
      await c.read(manualCityProvider.notifier).select(_dubaiCity);
      (c.read(authSessionProvider.notifier) as _SwitchSession).signedInNow();

      (c.read(authSessionProvider.notifier) as _SwitchSession).signOutNow();
      await Future<void>.delayed(Duration.zero);

      expect(repo.calls, contains('clearCache'));
      expect(c.read(manualCityProvider), _dubaiCity);
    });

    test('a guest staying a guest clears nothing', () async {
      final c = make();
      c.read(prayerTimesLoaderProvider);
      await Future<void>.delayed(Duration.zero);
      expect(repo.calls, isNot(contains('clearCache')));
    });
  });

  group('methods list', () {
    test('uses the server list, in its order and wording', () async {
      repo.methodsResult = const Success([
        CalculationMethodOption(id: 3, name: 'Muslim World League (server)'),
        CalculationMethodOption(id: 1, name: 'Karachi (server)'),
      ]);
      final c = make();
      final options = await c.read(prayerMethodOptionsProvider.future);
      expect(options.map((o) => o.method.id), [3, 1]);
      expect(options.first.label, 'Muslim World League (server)');
    });

    test('ids this app does not know are skipped', () async {
      repo.methodsResult = const Success([
        CalculationMethodOption(id: 99, name: 'Future method'),
        CalculationMethodOption(id: 1, name: 'Karachi'),
      ]);
      final options = await make().read(prayerMethodOptionsProvider.future);
      expect(options.map((o) => o.method.id), [1]);
    });

    test('offline, the built-in list stands in', () async {
      repo.methodsResult = const Error(NetworkFailure());
      final options = await make().read(prayerMethodOptionsProvider.future);
      expect(options, hasLength(PrayerCalculationMethod.values.length));
      expect(options.any((o) => o.method.id == 6), isFalse);
    });

    test('an empty server list falls back too', () async {
      repo.methodsResult = const Success([]);
      final options = await make().read(prayerMethodOptionsProvider.future);
      expect(options, hasLength(PrayerCalculationMethod.values.length));
    });
  });
}

/// Session that can sign in and out during a test.
class _SwitchSession extends AuthSessionNotifier {
  @override
  AuthSession build() => const AuthSession.guest();

  void signedInNow() => state = const AuthSession(userId: 'u1', email: 'a@b.c');
  void signOutNow() => state = const AuthSession.guest();
}

/// Delays the guest request so tests can overlap refreshes.
class _SlowRepo extends FakePrayerRepo {
  final FakePrayerRepo inner;
  final Future<void> gate;
  int guestCalls = 0;
  _SlowRepo(this.inner, this.gate) {
    guestResult = inner.guestResult;
  }

  @override
  Future<Result<PrayerTimesBundle>> fetchGuestTimes(
    Coordinates coordinates, {
    int? method,
    int? school,
    int days = 31,
  }) async {
    guestCalls++;
    await gate;
    return guestResult;
  }
}
