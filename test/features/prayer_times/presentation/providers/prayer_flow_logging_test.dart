import 'package:deen_companion/core/device/device_id_store.dart';
import 'package:deen_companion/core/di/providers.dart';
import 'package:deen_companion/core/error/failures.dart';
import 'package:deen_companion/core/location/location_service.dart';
import 'package:deen_companion/core/location/location_status.dart';
import 'package:deen_companion/core/usecase/usecase.dart';
import 'package:deen_companion/core/utils/flow_log.dart';
import 'package:deen_companion/features/auth/presentation/providers/auth_session_provider.dart';
import 'package:deen_companion/features/prayer_times/domain/entities/prayer_calculation_settings.dart';
import 'package:deen_companion/features/prayer_times/domain/entities/prayer_times_bundle.dart';
import 'package:deen_companion/features/prayer_times/presentation/providers/manual_city_provider.dart';
import 'package:deen_companion/features/prayer_times/presentation/providers/prayer_calculation_settings_provider.dart';
import 'package:deen_companion/features/prayer_times/presentation/providers/prayer_times_loader.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../_support/prayer_area_support.dart';
import '../../../auth/_support/auth_fakes.dart';
import '../../../prayer_logs/presentation/_prayer_log_test_support.dart';

const _dubai = PrayerCity(
  name: 'Dubai',
  region: 'Dubai',
  country: 'United Arab Emirates',
  countryCode: 'AE',
  latitude: 25.2,
  longitude: 55.27,
  timezone: 'Asia/Dubai',
);

/// What the terminal would show for one pass through the new flow.
void main() {
  late List<String> lines;
  late FakePrayerRepo repo;
  late PaStorage storage;
  late PaLocation location;

  setUpAll(initFlavorForTests);

  setUp(() {
    lines = [];
    FlowLog.enabledOverride = true;
    FlowLog.sink = lines.add;
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

  tearDown(() {
    FlowLog.enabledOverride = null;
    FlowLog.sink = null;
  });

  ProviderContainer make({bool signedIn = false, String? quick = 'PK'}) {
    final c = ProviderContainer(
      overrides: [
        localStorageServiceProvider.overrideWithValue(storage),
        authSessionProvider.overrideWith(
          signedIn ? SignedIn.new : SignedOut.new,
        ),
        locationServiceProvider.overrideWithValue(location),
        prayerTimesRepositoryProvider.overrideWithValue(repo),
        quickCountryProvider.overrideWithValue(quick),
        deviceCountryCodeProvider.overrideWith((ref) async => null),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  String all() => lines.join('\n');

  /// Position of the first line containing [text]; fails if absent.
  int at(String text) {
    final i = lines.indexWhere((l) => l.contains(text));
    expect(i, isNonNegative, reason: 'missing log: $text\n${all()}');
    return i;
  }

  void expectWellFormed() {
    expect(lines, isNotEmpty);
    for (final l in lines) {
      expect(l, startsWith('********** '), reason: l);
      expect(l, endsWith(' **********'), reason: l);
    }
  }

  test('guest refresh: the steps appear in order', () async {
    await make().read(prayerTimesLoaderProvider).refresh();

    final order = [
      '[PRAYER TIMES] REFRESH STARTED',
      '[PRAYER TIMES] ASKING THE DEVICE FOR ITS LOCATION',
      '[PRAYER TIMES] STEP 1 - place resolved',
      '[PRAYER TIMES] STEP 2 - who and what the user chose',
      '[USE CASE] DECIDING HOW TO GET TIMES  guest',
      '[USE CASE] DONE (guest)',
      '[PRAYER TIMES] STEP 3 - TIMES RECEIVED: 1 days',
      '[SETTINGS] ADOPTED SERVER SETTINGS',
    ];
    var last = -1;
    for (final step in order) {
      final i = at(step);
      expect(i, greaterThan(last), reason: step);
      last = i;
    }
    expectWellFormed();
  });

  test('the logs show what data is passed', () async {
    await make().read(prayerTimesLoaderProvider).refresh();
    final out = all();
    expect(out, contains('latitude: 31.5204'));
    expect(out, contains('country: PK'));
    expect(out, contains('chosenMethod: not chosen'));
    expect(out, contains('method: omit (server default)'));
  });

  test('signed-in first time explains the decision', () async {
    await make(signedIn: true).read(prayerTimesLoaderProvider).refresh();
    expect(all(), contains('DECIDING HOW TO GET TIMES  signed-in account'));
    expect(all(), contains('account has a saved location: false'));
    expect(
      all(),
      contains('FIRST TIME ON THIS ACCOUNT -> PUT /prayers/location'),
    );
    expect(all(), contains('[USE CASE] DONE (account)'));
    expectWellFormed();
  });

  test('a user change is traced from the tap to the server', () async {
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
    final c = make(signedIn: true);
    await c
        .read(prayerCalculationSettingsProvider.notifier)
        .setMethod(PrayerCalculationMethod.egyptian);
    await c.read(prayerTimesLoaderProvider).refresh();

    final picked = at('[SETTINGS] USER PICKED METHOD: 5');
    final changed = at('USER CHANGED METHOD/SCHOOL -> PUT /prayers/location');
    final synced = at('[SETTINGS] USER CHANGE REACHED THE SERVER');
    expect(changed, greaterThan(picked));
    expect(synced, greaterThan(changed));
  });

  test('no change and the same place sends nothing, and says so', () async {
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
    await make(signedIn: true).read(prayerTimesLoaderProvider).refresh();
    expect(all(), contains('SAME PLACE, NO USER CHANGE -> NOTHING TO SEND'));
  });

  test('a picked city and a joined refresh are explained', () async {
    final c = make();
    await c.read(manualCityProvider.notifier).select(_dubai);
    final l = c.read(prayerTimesLoaderProvider);
    final a = l.refresh();
    final b = l.refresh();
    await Future.wait([a, b]);

    expect(all(), contains('[CITY] USER PICKED A CITY'));
    expect(
      all(),
      contains('USING THE PICKED CITY: Dubai, United Arab Emirates'),
    );
    expect(all(), contains('REFRESH ALREADY RUNNING -> JOINING IT'));
  });

  test('a location problem is reported as an error line', () async {
    location.error = locErr(LocationErrorKind.permissionDenied);
    await make().read(prayerTimesLoaderProvider).refresh();
    expect(all(), contains('ERROR: NO LOCATION AVAILABLE (permissionDenied)'));
    expectWellFormed();
  });

  test('a failed fetch is reported', () async {
    repo.guestResult = const Error(NetworkFailure());
    await make().read(prayerTimesLoaderProvider).refresh();
    expect(all(), contains('ERROR: GUEST FETCH FAILED'));
    expect(all(), contains('ERROR: REFRESH FAILED'));
  });

  test('device id logs are shortened, never the full id', () async {
    final store = DeviceIdStore(storage);
    final id = await store.get();
    expect(all(), contains('NEW DEVICE ID CREATED'));
    expect(all(), isNot(contains(id)));
    await DeviceIdStore(storage).get();
    expect(all(), contains('DEVICE ID LOADED'));
  });

  test('auth changes are logged without the token or e-mail', () async {
    final c = ProviderContainer(
      overrides: [
        localStorageServiceProvider.overrideWithValue(storage),
        tokenStorageProvider.overrideWithValue(MemoryTokens(access: 'tok')),
      ],
    );
    addTearDown(c.dispose);
    // Build the real notifier as a guest, then sign out.
    c.read(authSessionProvider);
    await c.read(authSessionProvider.notifier).signOut();
    expect(all(), contains('[AUTH] NO SAVED SESSION -> GUEST'));
    expect(all(), contains('[AUTH] SIGNED OUT'));
    expect(all(), isNot(contains('@')));
  });

  test('nothing is printed when logging is off', () async {
    FlowLog.enabledOverride = false;
    await make().read(prayerTimesLoaderProvider).refresh();
    expect(lines, isEmpty);
  });

  test('a full flow never prints anything secret', () async {
    final c = make(signedIn: true);
    await c
        .read(prayerCalculationSettingsProvider.notifier)
        .setMethod(PrayerCalculationMethod.egyptian);
    await c.read(prayerTimesLoaderProvider).refresh();
    for (final secret in ['password', 'Bearer', 'accessToken', 'otp:']) {
      expect(all(), isNot(contains(secret)), reason: secret);
    }
    expectWellFormed();
  });
}
