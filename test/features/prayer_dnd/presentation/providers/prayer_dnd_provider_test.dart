import 'package:deen_companion/core/constants/app_constants.dart';
import 'package:deen_companion/core/di/providers.dart';
import 'package:deen_companion/core/usecase/usecase.dart';
import 'package:deen_companion/features/prayer_dnd/data/prayer_dnd_channel.dart';
import 'package:deen_companion/features/prayer_dnd/domain/dnd_settings.dart';
import 'package:deen_companion/features/prayer_dnd/domain/dnd_window.dart';
import 'package:deen_companion/features/prayer_dnd/presentation/providers/prayer_dnd_provider.dart';
import 'package:deen_companion/features/prayer_times/domain/entities/prayer_times.dart';
import 'package:deen_companion/features/prayer_times/presentation/providers/prayer_times_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../_support/prayer_area_support.dart';

class _MockChannel extends Mock implements PrayerDndChannel {}

void main() {
  late PaStorage storage;
  late FakePrayerRepo repo;
  late _MockChannel channel;
  const box = AppConstants.settingsBoxName;

  setUpAll(() {
    initFlavorForTests();
    registerFallbackValue(<DndWindow>[]);
  });

  setUp(() {
    storage = PaStorage();
    repo = FakePrayerRepo();
    channel = _MockChannel();
    when(() => channel.cancelAll()).thenAnswer((_) async {});
  });

  ProviderContainer make() {
    final c = ProviderContainer(
      overrides: [
        localStorageServiceProvider.overrideWithValue(storage),
        prayerTimesRepositoryProvider.overrideWithValue(repo),
        prayerDndChannelProvider.overrideWithValue(channel),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  Map<String, dynamic> settingsBox() => storage.boxes[box] ??= {};

  group('DndSettingsNotifier.build', () {
    test('empty storage -> defaults', () {
      final s = make().read(dndSettingsProvider);
      expect(s.enabled, isFalse);
      expect(s.mode, DndDurationMode.preset);
      expect(s.durations, isEmpty);
    });

    test('reads the stored per-prayer map, ignoring invalid entries', () {
      settingsBox().addAll({
        AppConstants.dndEnabledKey: true,
        AppConstants.dndDurationModeKey: 'custom',
        AppConstants.dndDurationsKey: {
          'fajr': 20,
          'dhuhr': 0,
          'asr': -3,
          'maghrib': '15',
          'isha': 45,
          'unknown': 10,
        },
      });
      final s = make().read(dndSettingsProvider);
      expect(s.enabled, isTrue);
      expect(s.mode, DndDurationMode.custom);
      expect(s.durations, {PrayerName.fajr: 20, PrayerName.isha: 45});
    });

    test('unknown stored mode name falls back to preset', () {
      settingsBox()[AppConstants.dndDurationModeKey] = 'until_next_prayer';
      expect(make().read(dndSettingsProvider).mode, DndDurationMode.preset);
    });

    test(
      'legacy preset migration: all prayers get the preset minutes and are persisted',
      () {
        settingsBox().addAll({
          AppConstants.dndDurationModeKey: 'preset',
          AppConstants.dndPresetMinutesKey: 30,
        });
        final s = make().read(dndSettingsProvider);
        expect(s.durations.keys.toSet(), PrayerName.values.toSet());
        expect(s.durations.values.toSet(), {30});
        expect(settingsBox()[AppConstants.dndDurationsKey], isA<Map>());
      },
    );

    test('legacy preset without stored minutes defaults to 20', () {
      settingsBox()[AppConstants.dndDurationModeKey] = 'preset';
      expect(make().read(dndSettingsProvider).durations[PrayerName.fajr], 20);
    });

    test(
      'legacy custom migration is limited to the stored prayers and clamped',
      () {
        settingsBox().addAll({
          AppConstants.dndDurationModeKey: 'custom',
          AppConstants.dndCustomMinutesKey: 500,
          AppConstants.dndPrayersKey: ['fajr', 'isha'],
        });
        expect(make().read(dndSettingsProvider).durations, {
          PrayerName.fajr: 120,
          PrayerName.isha: 120,
        });
      },
    );

    test('legacy custom with no stored minutes migrates nothing', () {
      settingsBox()[AppConstants.dndDurationModeKey] = 'custom';
      expect(make().read(dndSettingsProvider).durations, isEmpty);
    });

    test('legacy "until next prayer" mode migrates nothing', () {
      settingsBox()[AppConstants.dndDurationModeKey] = 'untilNext';
      expect(make().read(dndSettingsProvider).durations, isEmpty);
    });

    test('new per-prayer map wins over legacy keys', () {
      settingsBox().addAll({
        AppConstants.dndDurationModeKey: 'preset',
        AppConstants.dndPresetMinutesKey: 60,
        AppConstants.dndDurationsKey: {'fajr': 10},
      });
      expect(make().read(dndSettingsProvider).durations, {PrayerName.fajr: 10});
    });
  });

  group('DndSettingsNotifier mutations', () {
    test('setEnabled and setMode persist', () async {
      final c = make();
      final n = c.read(dndSettingsProvider.notifier);
      await n.setEnabled(true);
      await n.setMode(DndDurationMode.custom);
      expect(c.read(dndSettingsProvider).enabled, isTrue);
      expect(settingsBox()[AppConstants.dndEnabledKey], true);
      expect(settingsBox()[AppConstants.dndDurationModeKey], 'custom');
    });

    test('setDuration clamps to 1..120 and stores by prayer name', () async {
      final c = make();
      final n = c.read(dndSettingsProvider.notifier);
      await n.setDuration(PrayerName.fajr, 0);
      await n.setDuration(PrayerName.dhuhr, 999);
      await n.setDuration(PrayerName.asr, 45);
      expect(c.read(dndSettingsProvider).durations, {
        PrayerName.fajr: 1,
        PrayerName.dhuhr: 120,
        PrayerName.asr: 45,
      });
      expect(settingsBox()[AppConstants.dndDurationsKey], {
        'fajr': 1,
        'dhuhr': 120,
        'asr': 45,
      });
    });

    test('setDuration replaces an existing value', () async {
      final c = make();
      final n = c.read(dndSettingsProvider.notifier);
      await n.setDuration(PrayerName.fajr, 15);
      await n.setDuration(PrayerName.fajr, 30);
      expect(c.read(dndSettingsProvider).minutesFor(PrayerName.fajr), 30);
    });

    test('clearDuration removes only that prayer', () async {
      final c = make();
      final n = c.read(dndSettingsProvider.notifier);
      await n.setAllDurations(20);
      await n.clearDuration(PrayerName.asr);
      final d = c.read(dndSettingsProvider).durations;
      expect(d.containsKey(PrayerName.asr), isFalse);
      expect(d.length, 4);
    });

    test('setAllDurations covers all five, clamped', () async {
      final c = make();
      await c.read(dndSettingsProvider.notifier).setAllDurations(-4);
      final d = c.read(dndSettingsProvider).durations;
      expect(d.length, 5);
      expect(d.values.toSet(), {1});
    });

    test('clearAllDurations empties and persists the empty map', () async {
      final c = make();
      final n = c.read(dndSettingsProvider.notifier);
      await n.setAllDurations(15);
      await n.clearAllDurations();
      expect(c.read(dndSettingsProvider).configuredCount, 0);
      expect(settingsBox()[AppConstants.dndDurationsKey], isEmpty);
      // An empty persisted map must NOT trigger legacy migration next launch.
      expect(make().read(dndSettingsProvider).configuredCount, 0);
    });

    test('state survives a fresh container', () async {
      final c1 = make();
      await c1
          .read(dndSettingsProvider.notifier)
          .setDuration(PrayerName.isha, 25);
      await c1.read(dndSettingsProvider.notifier).setEnabled(true);
      final s = make().read(dndSettingsProvider);
      expect(s.enabled, isTrue);
      expect(s.durations, {PrayerName.isha: 25});
    });
  });

  group('PrayerDndService', () {
    void giveDays(List<PrayerTimes> days) {
      for (var m = 1; m <= 12; m++) {
        repo.months[m] = Success(days);
      }
    }

    PrayerTimes futureDay() {
      final now = DateTime.now();
      DateTime at(int h) => now.add(Duration(hours: h));
      return PrayerTimes(
        fajr: at(1),
        dhuhr: at(2),
        asr: at(3),
        maghrib: at(4),
        isha: at(5),
        hijriDate: '',
      );
    }

    test('syncIfEnabled does nothing when disabled', () async {
      final r = await make().read(prayerDndServiceProvider).syncIfEnabled();
      expect(r, isA<DndSyncDisabled>());
      verifyNever(() => channel.pushSchedule(any()));
    });

    test(
      'enabled but nothing configured: cancels and reports not-configured',
      () async {
        final c = make();
        await c.read(dndSettingsProvider.notifier).setEnabled(true);
        final r = await c.read(prayerDndServiceProvider).syncIfEnabled();
        expect(r, isA<DndSyncNothingConfigured>());
        verify(() => channel.cancelAll()).called(1);
        verifyNever(() => channel.pushSchedule(any()));
      },
    );

    test(
      'pushes only configured prayers and reports native armed count',
      () async {
        giveDays([futureDay()]);
        when(() => channel.pushSchedule(any())).thenAnswer((_) async => 2);
        final c = make();
        final n = c.read(dndSettingsProvider.notifier);
        await n.setEnabled(true);
        await n.setDuration(PrayerName.dhuhr, 20);
        await n.setDuration(PrayerName.isha, 30);
        final r = await c.read(prayerDndServiceProvider).syncIfEnabled();
        expect((r as DndSyncScheduled).windowCount, 2);
        final windows =
            verify(() => channel.pushSchedule(captureAny())).captured.single
                as List<DndWindow>;
        expect(windows.map((w) => w.prayerName), ['dhuhr', 'isha']);
        expect(
          windows.first.end.difference(windows.first.start),
          const Duration(minutes: 20),
        );
      },
    );

    test('prayer times unavailable -> DndSyncFailed, nothing pushed', () async {
      final c = make();
      await c
          .read(dndSettingsProvider.notifier)
          .setDuration(PrayerName.fajr, 10);
      final r = await c.read(prayerDndServiceProvider).sync();
      expect(r, isA<DndSyncFailed>());
      verifyNever(() => channel.pushSchedule(any()));
    });

    test('native unavailable (null) -> DndSyncFailed', () async {
      giveDays([futureDay()]);
      when(() => channel.pushSchedule(any())).thenAnswer((_) async => null);
      final c = make();
      await c
          .read(dndSettingsProvider.notifier)
          .setDuration(PrayerName.fajr, 10);
      final r = await c.read(prayerDndServiceProvider).sync();
      expect((r as DndSyncFailed).message, contains('not available'));
    });

    test('cancelAll delegates', () async {
      await make().read(prayerDndServiceProvider).cancelAll();
      verify(() => channel.cancelAll()).called(1);
    });
  });

  group('dndUpcomingTimesProvider', () {
    test(
      'picks the earliest future occurrence per prayer, skipping past ones',
      () async {
        final now = DateTime.now();
        PrayerTimes day(int offsetDays, {required int fajrH}) {
          DateTime at(int h) => now.add(Duration(days: offsetDays, hours: h));
          return PrayerTimes(
            fajr: at(fajrH),
            dhuhr: at(2),
            asr: at(3),
            maghrib: at(4),
            isha: at(5),
            hijriDate: '',
          );
        }

        final today = day(0, fajrH: -3); // fajr already passed
        final tomorrow = day(1, fajrH: -3); // tomorrow's fajr is ~21h away
        for (var m = 1; m <= 12; m++) {
          repo.months[m] = Success([tomorrow, today]);
        }
        final c = make();
        final result = await c.read(dndUpcomingTimesProvider.future);
        expect(result[PrayerName.fajr], tomorrow.fajr);
        expect(result[PrayerName.dhuhr], today.dhuhr);
        expect(result.keys.toSet(), PrayerName.values.toSet());
      },
    );

    test('no data yields an empty map', () async {
      expect(await make().read(dndUpcomingTimesProvider.future), isEmpty);
    });
  });
}
