import 'dart:async';

import 'package:deen_companion/core/constants/app_constants.dart';
import 'package:deen_companion/core/di/providers.dart';
import 'package:deen_companion/core/location/location_service.dart';
import 'package:deen_companion/features/prayer_times/domain/entities/prayer_calculation_settings.dart';
import 'package:deen_companion/features/prayer_times/presentation/providers/prayer_calculation_settings_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../_support/prayer_area_support.dart';

void main() {
  late PaStorage storage;

  /// [quick] is the timezone-derived country and [country] what the device
  /// location resolves to; both default to "unknown", so the world defaults
  /// apply whatever timezone this machine is in.
  ProviderContainer make({String? quick, Future<String?> Function()? country}) {
    final c = ProviderContainer(
      overrides: [
        localStorageServiceProvider.overrideWithValue(storage),
        quickCountryProvider.overrideWithValue(quick),
        deviceCountryCodeProvider.overrideWith(
          (ref) => (country ?? () async => null)(),
        ),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  Map<String, dynamic> saved() => Map<String, dynamic>.from(
    storage.boxes[AppConstants.settingsBoxName] ?? {},
  );

  /// Lets the notifier's background work (microtasks, storage writes) finish.
  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 20));

  setUp(() => storage = PaStorage());

  test('defaults to the MWL / Shafi fallback when nothing stored', () {
    final s = make().read(prayerCalculationSettingsProvider);
    expect(s.method, PrayerCalculationMethod.muslimWorldLeague);
    expect(s.school, AsrSchool.shafi);
  });

  test('restores stored ids', () {
    storage.boxes[AppConstants.settingsBoxName] = {
      'prayer_calculation_method': 1,
      'prayer_asr_school': 1,
    };
    final s = make().read(prayerCalculationSettingsProvider);
    expect(s.method, PrayerCalculationMethod.karachi);
    expect(s.school, AsrSchool.hanafi);
  });

  test('unknown / retired ids (6, 99, -1) fall back instead of crashing', () {
    for (final bad in [6, 99, -1]) {
      storage.boxes[AppConstants.settingsBoxName] = {
        'prayer_calculation_method': bad,
        'prayer_asr_school': bad,
      };
      final s = make().read(prayerCalculationSettingsProvider);
      expect(s.method, PrayerCalculationSettings.fallback.method);
      expect(s.school, PrayerCalculationSettings.fallback.school);
    }
  });

  test('setMethod updates state and persists only the method id', () async {
    final c = make();
    await c
        .read(prayerCalculationSettingsProvider.notifier)
        .setMethod(PrayerCalculationMethod.ummAlQura);
    expect(
      c.read(prayerCalculationSettingsProvider).method,
      PrayerCalculationMethod.ummAlQura,
    );
    final box = storage.boxes[AppConstants.settingsBoxName]!;
    expect(box['prayer_calculation_method'], 4);
    expect(box.containsKey('prayer_asr_school'), isFalse);
  });

  test('setSchool keeps method and persists school id', () async {
    final c = make();
    final n = c.read(prayerCalculationSettingsProvider.notifier);
    await n.setMethod(PrayerCalculationMethod.egyptian);
    await n.setSchool(AsrSchool.hanafi);
    final s = c.read(prayerCalculationSettingsProvider);
    expect(s.method, PrayerCalculationMethod.egyptian);
    expect(s.school, AsrSchool.hanafi);
    expect(
      storage.boxes[AppConstants.settingsBoxName]!['prayer_asr_school'],
      1,
    );
  });

  test('persisted choice survives a fresh container', () async {
    final c1 = make();
    await c1
        .read(prayerCalculationSettingsProvider.notifier)
        .setMethod(PrayerCalculationMethod.turkeyDiyanet);
    final c2 = make();
    expect(
      c2.read(prayerCalculationSettingsProvider).method,
      PrayerCalculationMethod.turkeyDiyanet,
    );
  });

  group('regional defaults', () {
    test(
      'a Pakistani timezone starts on Karachi / Hanafi and saves both',
      () async {
        final c = make(quick: 'PK');
        final s = c.read(prayerCalculationSettingsProvider);
        expect(s.method, PrayerCalculationMethod.karachi);
        expect(s.school, AsrSchool.hanafi);
        await settle();
        expect(saved()['prayer_calculation_method'], 1);
        expect(saved()['prayer_asr_school'], 1);
      },
    );

    test('only the unchosen setting gets the regional default', () async {
      // Chose Hanafi already; the method is still unchosen.
      storage.boxes[AppConstants.settingsBoxName] = {'prayer_asr_school': 1};
      final c = make(quick: 'PK');
      expect(
        c.read(prayerCalculationSettingsProvider).method,
        PrayerCalculationMethod.karachi,
      );
      await settle();
      expect(saved()['prayer_calculation_method'], 1);

      // Chose Egyptian + Shafi on purpose: untouched.
      storage.boxes[AppConstants.settingsBoxName] = {
        'prayer_calculation_method': 5,
        'prayer_asr_school': 0,
      };
      final c2 = make(quick: 'PK');
      final s = c2.read(prayerCalculationSettingsProvider);
      expect(s.method, PrayerCalculationMethod.egyptian);
      expect(s.school, AsrSchool.shafi);
      await settle();
      expect(saved()['prayer_calculation_method'], 5);
      expect(saved()['prayer_asr_school'], 0);
    });

    test(
      'a user-chosen method in Pakistan is kept, school still defaults',
      () async {
        storage.boxes[AppConstants.settingsBoxName] = {
          'prayer_calculation_method': 3,
        };
        final c = make(quick: 'PK');
        final s = c.read(prayerCalculationSettingsProvider);
        expect(s.method, PrayerCalculationMethod.muslimWorldLeague);
        expect(s.school, AsrSchool.hanafi);
      },
    );

    test(
      'no timezone hint: location in Pakistan switches the defaults',
      () async {
        final c = make(country: () async => 'PK');
        expect(
          c.read(prayerCalculationSettingsProvider).method,
          PrayerCalculationMethod.muslimWorldLeague,
          reason: 'world defaults until the country is known',
        );
        await settle();
        final s = c.read(prayerCalculationSettingsProvider);
        expect(s.method, PrayerCalculationMethod.karachi);
        expect(s.school, AsrSchool.hanafi);
        expect(saved()['prayer_calculation_method'], 1);
      },
    );

    test(
      'another country keeps the world defaults and saves nothing',
      () async {
        final c = make(country: () async => 'AE');
        await settle();
        final s = c.read(prayerCalculationSettingsProvider);
        expect(s.method, PrayerCalculationMethod.muslimWorldLeague);
        expect(s.school, AsrSchool.shafi);
        expect(saved(), isEmpty);
      },
    );

    test(
      'unknown country saves nothing, so it is retried next launch',
      () async {
        final c = make();
        await settle();
        c.read(prayerCalculationSettingsProvider);
        await settle();
        expect(saved(), isEmpty);
      },
    );

    test('a failed country lookup is ignored', () async {
      final c = make(country: () async => throw Exception('geocoder down'));
      c.read(prayerCalculationSettingsProvider);
      await settle();
      expect(saved(), isEmpty);
    });

    test('a manual choice made while the country resolves wins', () async {
      final gate = Completer<String?>();
      final c = make(country: () => gate.future);
      final n = c.read(prayerCalculationSettingsProvider.notifier);
      await n.setMethod(PrayerCalculationMethod.egyptian);

      gate.complete('PK');
      await settle();

      final s = c.read(prayerCalculationSettingsProvider);
      expect(s.method, PrayerCalculationMethod.egyptian);
      expect(s.school, AsrSchool.hanafi, reason: 'the unchosen one defaults');
      expect(saved()['prayer_calculation_method'], 5);
    });

    test(
      'later choices are never overridden by the regional default',
      () async {
        final c = make(quick: 'PK');
        await settle();
        await c
            .read(prayerCalculationSettingsProvider.notifier)
            .setSchool(AsrSchool.shafi);
        final c2 = make(quick: 'PK');
        expect(
          c2.read(prayerCalculationSettingsProvider).school,
          AsrSchool.shafi,
        );
      },
    );
  });
}
