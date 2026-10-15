import 'package:deen_companion/core/di/providers.dart';
import 'package:deen_companion/core/error/failures.dart';
import 'package:deen_companion/core/location/location_service.dart';
import 'package:deen_companion/core/usecase/usecase.dart';
import 'package:deen_companion/features/auth/domain/entities/auth_session.dart';
import 'package:deen_companion/features/auth/presentation/providers/auth_session_provider.dart';
import 'package:deen_companion/features/prayer_times/domain/entities/prayer_calculation_settings.dart';
import 'package:deen_companion/features/prayer_times/domain/entities/prayer_times.dart';
import 'package:deen_companion/features/prayer_times/domain/entities/prayer_times_bundle.dart';
import 'package:deen_companion/features/prayer_times/presentation/providers/manual_city_provider.dart';
import 'package:deen_companion/features/prayer_times/presentation/providers/prayer_calculation_settings_provider.dart';
import 'package:deen_companion/features/prayer_times/presentation/providers/prayer_times_loader.dart';
import 'package:deen_companion/features/prayer_times/presentation/providers/prayer_times_provider.dart';
import 'package:deen_companion/features/prayer_times/presentation/providers/upcoming_prayer_days.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../_support/prayer_area_support.dart';
import '../../../prayer_logs/presentation/_prayer_log_test_support.dart';

class _NoRecovery extends LocationRecoveryNotifier {
  @override
  int build() => 0;
}

/// Days around "now" so [todayOf] and the upcoming-days window behave the
/// same whenever the suite runs.
PrayerTimes dayFromNow(int offsetDays, {int fajrHour = 5}) {
  final base = DateTime.now().add(Duration(days: offsetDays));
  DateTime at(int h) => DateTime(base.year, base.month, base.day, h);
  return PrayerTimes(
    fajr: at(fajrHour),
    dhuhr: at(12),
    asr: at(15),
    maghrib: at(18),
    isha: at(19),
    hijriDate: 'h',
  );
}

/// Lets the notifier's stream finish its cache-then-fetch sequence.
Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 20));

void main() {
  late FakePrayerRepo repo;
  late FakePrayerTimesLoader loader;
  late PaStorage storage;

  setUpAll(initFlavorForTests);

  setUp(() {
    repo = FakePrayerRepo();
    storage = PaStorage();
  });

  ProviderContainer make({bool signedIn = false}) {
    final c = ProviderContainer(
      overrides: [
        localStorageServiceProvider.overrideWithValue(storage),
        authSessionProvider.overrideWith(
          signedIn ? SignedIn.new : SignedOut.new,
        ),
        prayerTimesRepositoryProvider.overrideWithValue(repo),
        prayerTimesLoaderProvider.overrideWith((ref) {
          return loader = FakePrayerTimesLoader(ref, repo);
        }),
        locationServiceProvider.overrideWithValue(PaLocation()),
        locationRecoveryProvider.overrideWith(_NoRecovery.new),
        // World defaults, whatever timezone the test machine is in.
        quickCountryProvider.overrideWithValue(null),
        deviceCountryCodeProvider.overrideWith((ref) async => null),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  group('PrayerTimesNotifier', () {
    test('no cache: emits the fresh day', () async {
      final fresh = dayFromNow(0);
      final c = make();
      // The loader answers from the repository's cache.
      repo.bundle = bundleOf([fresh]);
      // …but nothing is cached when the notifier first reads.
      final v = await c.read(prayerTimesNotifierProvider.future);
      expect(v, fresh);
    });

    test('cache first, then the fresh value if it differs', () async {
      final cached = dayFromNow(0, fajrHour: 5);
      final fresh = dayFromNow(0, fajrHour: 4);
      repo.bundle = bundleOf([cached]);
      final c = make();
      // Fresh answer from the loader differs from the cache.
      c.read(prayerTimesLoaderProvider);
      loader.result = Success(bundleOf([fresh]));

      final seen = <PrayerTimes>[];
      final sub = c.listen(prayerTimesNotifierProvider, (_, n) {
        if (n.hasValue) seen.add(n.value!);
      }, fireImmediately: true);
      addTearDown(sub.close);
      await c.read(prayerTimesNotifierProvider.future);
      await Future<void>.delayed(Duration.zero);

      expect(seen.first, cached);
      expect(seen.last, fresh);
    });

    test('a failure with a cache keeps showing the cache', () async {
      final cached = dayFromNow(0);
      repo.bundle = bundleOf([cached]);
      final c = make();
      c.read(prayerTimesLoaderProvider);
      loader.result = const Error(NetworkFailure());

      final v = await c.read(prayerTimesNotifierProvider.future);
      expect(v, cached);
      expect(c.read(prayerTimesNotifierProvider).hasError, isFalse);
    });

    test('a failure without a cache is the error', () async {
      final c = make();
      c.read(prayerTimesLoaderProvider);
      loader.result = const Error(NetworkFailure());
      await expectLater(
        c.read(prayerTimesNotifierProvider.future),
        throwsA(isA<NetworkFailure>()),
      );
    });

    test('a bundle with no days is an error, not an empty screen', () async {
      final c = make();
      c.read(prayerTimesLoaderProvider);
      loader.result = Success(bundleOf([]));
      await expectLater(
        c.read(prayerTimesNotifierProvider.future),
        throwsA(isA<ServerFailure>()),
      );
    });

    /// Opens the notifier and keeps it listened to (as a screen would), so
    /// a changed dependency rebuilds it.
    Future<ProviderContainer> open() async {
      repo.bundle = bundleOf([dayFromNow(0)]);
      final c = make();
      c.read(prayerTimesLoaderProvider); // creates the fake loader
      final sub = c.listen(prayerTimesNotifierProvider, (_, _) {});
      addTearDown(sub.close);
      await settle();
      return c;
    }

    test('opening fetches once', () async {
      await open();
      expect(loader.refreshes, 1);
    });

    test('a user change of method refetches', () async {
      final c = await open();
      final before = loader.refreshes;

      await c
          .read(prayerCalculationSettingsProvider.notifier)
          .setMethod(PrayerCalculationMethod.egyptian);
      await settle();

      expect(loader.refreshes, before + 1);
    });

    test('adopting the server settings does NOT refetch', () async {
      final c = await open();
      final before = loader.refreshes;

      await c
          .read(prayerCalculationSettingsProvider.notifier)
          .adopt(methodId: 5, schoolId: 0);
      await settle();

      expect(loader.refreshes, before);
    });

    test('picking a city refetches', () async {
      final c = await open();
      final before = loader.refreshes;

      await c.read(manualCityProvider.notifier).select(_city);
      await settle();

      expect(loader.refreshes, before + 1);
    });

    test('signing in refetches (guest and account times differ)', () async {
      repo.bundle = bundleOf([dayFromNow(0)]);
      final c = ProviderContainer(
        overrides: [
          localStorageServiceProvider.overrideWithValue(storage),
          authSessionProvider.overrideWith(_ToggleSession.new),
          prayerTimesRepositoryProvider.overrideWithValue(repo),
          prayerTimesLoaderProvider.overrideWith((ref) {
            return loader = FakePrayerTimesLoader(ref, repo);
          }),
          locationServiceProvider.overrideWithValue(PaLocation()),
          locationRecoveryProvider.overrideWith(_NoRecovery.new),
          quickCountryProvider.overrideWithValue(null),
          deviceCountryCodeProvider.overrideWith((ref) async => null),
        ],
      );
      addTearDown(c.dispose);
      c.read(prayerTimesLoaderProvider);
      final sub = c.listen(prayerTimesNotifierProvider, (_, _) {});
      addTearDown(sub.close);
      await settle();
      final before = loader.refreshes;

      (c.read(authSessionProvider.notifier) as _ToggleSession).signInAs('u1');
      await settle();

      expect(loader.refreshes, before + 1);
    });

    test('refresh() fetches again', () async {
      final c = await open();
      final before = loader.refreshes;
      await c.read(prayerTimesNotifierProvider.notifier).refresh();
      await settle();
      expect(loader.refreshes, before + 1);
    });
  });

  group('source label', () {
    test('names the method and school of the cached bundle', () async {
      repo.bundle = bundleOf([dayFromNow(0)]);
      final c = make();
      await c.read(prayerTimesNotifierProvider.future);
      expect(
        c.read(prayerSourceLabelProvider),
        'Calculated: University of Islamic Sciences, Karachi, Hanafi Asr',
      );
    });

    test('is absent for unverified fallback times', () async {
      repo.bundle = _unverified([dayFromNow(0)]);
      final c = make();
      await c.read(prayerTimesNotifierProvider.future);
      expect(c.read(prayerSourceLabelProvider), isNull);
    });
  });

  group('PrayerCalendarNotifier', () {
    test(
      'a guest asks the guest month endpoint, applying the method rule',
      () async {
        repo.monthResult = Success(bundleOf([dayFromNow(0), dayFromNow(1)]));
        final c = make();
        // Unknown country, nothing chosen: nothing is sent.
        final days = await c.read(
          prayerCalendarNotifierProvider((year: 2026, month: 10)).future,
        );
        expect(days, hasLength(2));
        expect(repo.calls, ['guestMonth 2026-10']);
        expect(repo.lastSent, (method: null, school: null));
      },
    );

    test('a signed-in user asks the account month endpoint', () async {
      repo.monthResult = Success(bundleOf([dayFromNow(0)]));
      final c = make(signedIn: true);
      await c.read(
        prayerCalendarNotifierProvider((year: 2026, month: 11)).future,
      );
      expect(repo.calls, ['accountMonth 2026-11']);
    });

    test('a failure is thrown for the screen', () async {
      repo.monthResult = const Error(NetworkFailure());
      final c = make();
      await expectLater(
        c.read(prayerCalendarNotifierProvider((year: 2026, month: 10)).future),
        throwsA(isA<NetworkFailure>()),
      );
    });

    test('a chosen method is sent for guests', () async {
      repo.monthResult = Success(bundleOf([dayFromNow(0)]));
      final c = make();
      await c
          .read(prayerCalculationSettingsProvider.notifier)
          .setMethod(PrayerCalculationMethod.egyptian);
      await c.read(
        prayerCalendarNotifierProvider((year: 2026, month: 10)).future,
      );
      expect(repo.lastSent!.method, 5);
    });
  });

  group('loadUpcomingPrayerDays', () {
    test('enough cached days: no refresh at all', () async {
      repo.bundle = bundleOf([for (var i = 0; i < 9; i++) dayFromNow(i)]);
      final c = make();
      final r = await loadUpcomingPrayerDays(
        c.read(_refProvider),
        now: DateTime.now(),
        windowDays: 7,
      );
      expect(r.error, isNull);
      expect(r.days, hasLength(9));
      expect(loader.refreshes, 0);
    });

    test('too few cached days: refreshes once and reads again', () async {
      repo.bundle = bundleOf([dayFromNow(0)]);
      final c = make();
      final ref = c.read(_refProvider);
      c.read(prayerTimesLoaderProvider);
      loader.result = Success(bundleOf([dayFromNow(0)]));
      await loadUpcomingPrayerDays(ref, now: DateTime.now(), windowDays: 7);
      expect(loader.refreshes, 1);
    });

    test('past days are dropped', () async {
      repo.bundle = bundleOf([
        dayFromNow(-3),
        dayFromNow(-1),
        for (var i = 0; i < 9; i++) dayFromNow(i),
      ]);
      final c = make();
      final r = await loadUpcomingPrayerDays(
        c.read(_refProvider),
        now: DateTime.now(),
        windowDays: 7,
      );
      expect(r.days, hasLength(9));
      final today = DateTime.now();
      expect(r.days.first.fajr.day, today.day);
    });

    test('a failed refresh still returns what is cached', () async {
      repo.bundle = bundleOf([dayFromNow(0), dayFromNow(1)]);
      final c = make();
      final ref = c.read(_refProvider);
      c.read(prayerTimesLoaderProvider);
      loader.result = const Error(NetworkFailure());
      final r = await loadUpcomingPrayerDays(
        ref,
        now: DateTime.now(),
        windowDays: 7,
      );
      expect(r.error, isNull);
      expect(r.days, hasLength(2));
    });

    test('a failed refresh with an empty cache is an error message', () async {
      final c = make();
      final ref = c.read(_refProvider);
      c.read(prayerTimesLoaderProvider);
      loader.result = const Error(NetworkFailure());
      final r = await loadUpcomingPrayerDays(
        ref,
        now: DateTime.now(),
        windowDays: 7,
      );
      expect(r.days, isEmpty);
      expect(r.error, "You're offline. Check your connection.");
    });
  });
}

/// Session that can flip from guest to signed in during a test.
class _ToggleSession extends AuthSessionNotifier {
  @override
  AuthSession build() => const AuthSession.guest();

  void signInAs(String id) => state = AuthSession(userId: id, email: 'a@b.c');
}

const _city = PrayerCity(
  name: 'Dubai',
  region: 'Dubai',
  country: 'United Arab Emirates',
  countryCode: 'AE',
  latitude: 25.2,
  longitude: 55.27,
  timezone: 'Asia/Dubai',
);

/// What the Aladhan fallback produces: no method name, flagged unverified.
PrayerTimesBundle _unverified(List<PrayerTimes> days) {
  final b = bundleOf(days, unverified: true);
  return PrayerTimesBundle(
    location: b.location,
    method: const CalculationMethodInfo(
      id: 1,
      name: '',
      school: 'hanafi',
      schoolId: 1,
    ),
    days: b.days,
    isUnverified: true,
  );
}

/// A `Ref` for the helper functions that take one.
final _refProvider = Provider<Ref>((ref) => ref);
