import 'package:deen_companion/core/constants/app_constants.dart';
import 'package:deen_companion/core/di/providers.dart';
import 'package:deen_companion/features/prayer_times/domain/entities/prayer_calculation_settings.dart';
import 'package:deen_companion/features/prayer_times/presentation/providers/prayer_calculation_settings_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../_support/prayer_area_support.dart';

void main() {
  late PaStorage storage;
  ProviderContainer make() {
    final c = ProviderContainer(
      overrides: [localStorageServiceProvider.overrideWithValue(storage)],
    );
    addTearDown(c.dispose);
    return c;
  }

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
}
