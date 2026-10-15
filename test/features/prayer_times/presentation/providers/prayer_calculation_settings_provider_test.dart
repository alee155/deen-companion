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
  /// location resolves to; both default to "unknown" so the result does not
  /// depend on the machine's timezone.
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

  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 20));

  PrayerCalculationSettingsNotifier notifierOf(ProviderContainer c) =>
      c.read(prayerCalculationSettingsProvider.notifier);

  setUp(() => storage = PaStorage());

  group('what is shown when nothing is decided', () {
    test('unknown country follows the server default: Karachi / Hanafi', () {
      final s = make().read(prayerCalculationSettingsProvider);
      expect(s.method, PrayerCalculationMethod.karachi);
      expect(s.school, AsrSchool.hanafi);
    });

    test('a Pakistani timezone shows Karachi / Hanafi at once', () {
      final s = make(quick: 'PK').read(prayerCalculationSettingsProvider);
      expect(s.method, PrayerCalculationMethod.karachi);
      expect(s.school, AsrSchool.hanafi);
    });

    test('a known country outside Pakistan shows MWL / Shafi', () async {
      final c = make(country: () async => 'AE');
      c.read(prayerCalculationSettingsProvider);
      await settle();
      final s = c.read(prayerCalculationSettingsProvider);
      expect(s.method, PrayerCalculationMethod.muslimWorldLeague);
      expect(s.school, AsrSchool.shafi);
    });

    test('defaults are never saved', () async {
      final c = make(quick: 'PK');
      c.read(prayerCalculationSettingsProvider);
      await settle();
      expect(saved(), isEmpty);
      expect(notifierOf(c).choice.methodId, isNull);
      expect(notifierOf(c).choice.schoolId, isNull);
    });

    test('a failed country lookup keeps the default', () async {
      final c = make(country: () async => throw Exception('geocoder down'));
      c.read(prayerCalculationSettingsProvider);
      await settle();
      expect(
        c.read(prayerCalculationSettingsProvider).method,
        PrayerCalculationMethod.karachi,
      );
    });
  });

  group('stored decisions', () {
    test('restores stored ids', () {
      storage.boxes[AppConstants.settingsBoxName] = {
        'prayer_calculation_method': 5,
        'prayer_asr_school': 0,
      };
      final s = make(quick: 'PK').read(prayerCalculationSettingsProvider);
      expect(s.method, PrayerCalculationMethod.egyptian);
      expect(s.school, AsrSchool.shafi);
    });

    test('unknown / retired ids (6, 99, -1) count as undecided', () {
      for (final bad in [6, 99, -1]) {
        storage.boxes[AppConstants.settingsBoxName] = {
          'prayer_calculation_method': bad,
          'prayer_asr_school': bad,
        };
        final c = make();
        final s = c.read(prayerCalculationSettingsProvider);
        expect(s.method, PrayerCalculationSettings.pakistan.method);
        expect(s.school, PrayerCalculationSettings.pakistan.school);
        expect(notifierOf(c).choice.methodId, isNull);
      }
    });

    test('a decision beats the regional default, per setting', () async {
      storage.boxes[AppConstants.settingsBoxName] = {'prayer_asr_school': 0};
      final c = make(country: () async => 'AE');
      c.read(prayerCalculationSettingsProvider);
      await settle();
      final s = c.read(prayerCalculationSettingsProvider);
      expect(s.school, AsrSchool.shafi, reason: 'chosen');
      expect(s.method, PrayerCalculationMethod.muslimWorldLeague);
    });
  });

  group('user changes', () {
    test(
      'setMethod updates state, saves only the method, flags a change',
      () async {
        final c = make();
        await notifierOf(c).setMethod(PrayerCalculationMethod.ummAlQura);
        expect(
          c.read(prayerCalculationSettingsProvider).method,
          PrayerCalculationMethod.ummAlQura,
        );
        expect(saved()['prayer_calculation_method'], 4);
        expect(saved().containsKey('prayer_asr_school'), isFalse);
        expect(notifierOf(c).choice.changedByUser, isTrue);
      },
    );

    test('each change bumps the revision so times refetch', () async {
      final c = make();
      expect(c.read(prayerSettingsRevisionProvider), 0);
      await notifierOf(c).setMethod(PrayerCalculationMethod.egyptian);
      await notifierOf(c).setSchool(AsrSchool.hanafi);
      expect(c.read(prayerSettingsRevisionProvider), 2);
    });

    test('setSchool keeps the method and persists the school id', () async {
      final c = make();
      final n = notifierOf(c);
      await n.setMethod(PrayerCalculationMethod.egyptian);
      await n.setSchool(AsrSchool.hanafi);
      final s = c.read(prayerCalculationSettingsProvider);
      expect(s.method, PrayerCalculationMethod.egyptian);
      expect(s.school, AsrSchool.hanafi);
      expect(saved()['prayer_asr_school'], 1);
    });

    test('a choice survives a fresh container', () async {
      final c1 = make();
      await notifierOf(c1).setMethod(PrayerCalculationMethod.turkeyDiyanet);
      final c2 = make();
      expect(
        c2.read(prayerCalculationSettingsProvider).method,
        PrayerCalculationMethod.turkeyDiyanet,
      );
    });

    test('markSynced clears the pending-change flag', () async {
      final c = make();
      await notifierOf(c).setSchool(AsrSchool.shafi);
      await notifierOf(c).markSynced();
      expect(notifierOf(c).choice.changedByUser, isFalse);
      expect(notifierOf(c).choice.schoolId, 0, reason: 'the choice stays');
    });
  });

  group('adopting the server values', () {
    test(
      'shows and saves them without flagging a change or refetching',
      () async {
        final c = make();
        await notifierOf(c).adopt(methodId: 5, schoolId: 0);
        final s = c.read(prayerCalculationSettingsProvider);
        expect(s.method, PrayerCalculationMethod.egyptian);
        expect(s.school, AsrSchool.shafi);
        expect(saved()['prayer_calculation_method'], 5);
        expect(notifierOf(c).choice.changedByUser, isFalse);
        expect(c.read(prayerSettingsRevisionProvider), 0);
      },
    );

    test('an id this app does not know is ignored', () async {
      final c = make();
      await notifierOf(c).adopt(methodId: 6, schoolId: 1);
      expect(saved(), isEmpty);
    });
  });
}
