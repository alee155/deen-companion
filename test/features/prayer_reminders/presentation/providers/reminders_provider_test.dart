import 'package:deen_companion/core/constants/app_constants.dart';
import 'package:deen_companion/core/di/providers.dart';
import 'package:deen_companion/core/error/failures.dart';
import 'package:deen_companion/core/usecase/usecase.dart';
import 'package:deen_companion/features/prayer_reminders/data/prayer_alarm_channel.dart';
import 'package:deen_companion/features/prayer_reminders/domain/prayer_reminder_prefs.dart';
import 'package:deen_companion/features/prayer_reminders/presentation/providers/reminders_provider.dart';
import 'package:deen_companion/features/prayer_times/domain/entities/prayer_times.dart';
import 'package:deen_companion/features/prayer_times/presentation/providers/prayer_times_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../_support/prayer_area_support.dart';

class _MockChannel extends Mock implements PrayerAlarmChannel {}

/// A day whose prayers sit [offsets] (hours) from now, so tests are
/// independent of the wall clock.
PrayerTimes dayFromNow(List<double> hours, {DateTime? base}) {
  final now = base ?? DateTime.now();
  DateTime at(double h) => now.add(Duration(minutes: (h * 60).round()));
  return PrayerTimes(
    fajr: at(hours[0]),
    dhuhr: at(hours[1]),
    asr: at(hours[2]),
    maghrib: at(hours[3]),
    isha: at(hours[4]),
    hijriDate: 'h',
  );
}

void main() {
  late PaStorage storage;
  late FakePrayerRepo repo;
  late _MockChannel channel;

  setUpAll(() {
    initFlavorForTests();
    registerFallbackValue(<PrayerAlarmEntry>[]);
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
        prayerAlarmChannelProvider.overrideWithValue(channel),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  void stubPush(int? armed) => when(
    () =>
        channel.pushSchedule(any(), snoozeMinutes: any(named: 'snoozeMinutes')),
  ).thenAnswer((_) async => armed);

  List<PrayerAlarmEntry> pushed() =>
      verify(
            () => channel.pushSchedule(
              captureAny(),
              snoozeMinutes: any(named: 'snoozeMinutes'),
            ),
          ).captured.last
          as List<PrayerAlarmEntry>;

  group('RemindersEnabledNotifier', () {
    test('defaults off, set persists', () async {
      final c = make();
      expect(c.read(remindersEnabledProvider), isFalse);
      await c.read(remindersEnabledProvider.notifier).set(true);
      expect(c.read(remindersEnabledProvider), isTrue);
      expect(
        storage.boxes[AppConstants.settingsBoxName]![AppConstants
            .remindersEnabledKey],
        true,
      );
      expect(make().read(remindersEnabledProvider), isTrue);
    });
  });

  group('PrayerReminderService.syncIfEnabled', () {
    test('disabled master switch does nothing', () async {
      final r = await make()
          .read(prayerReminderServiceProvider)
          .syncIfEnabled();
      expect(r, isA<ReminderSyncDisabled>());
      verifyNever(
        () => channel.pushSchedule(
          any(),
          snoozeMinutes: any(named: 'snoozeMinutes'),
        ),
      );
    });
  });

  group('PrayerReminderService.sync', () {
    // A window big enough to be a single "month" for the fake repo no matter
    // what today is: the fake returns the same days for any month.
    void giveDays(List<PrayerTimes> days) {
      for (var m = 1; m <= 12; m++) {
        repo.months[m] = Success(days);
      }
    }

    test(
      'arms only future prayers, sorted, with labels and snooze prefs',
      () async {
        // fajr/dhuhr already passed; asr, maghrib, isha upcoming.
        giveDays([
          dayFromNow([-5, -1, 1, 2, 3]),
        ]);
        stubPush(3);
        final c = make();
        await c
            .read(prayerReminderPrefsProvider.notifier)
            .update(
              PrayerName.asr,
              const PrayerReminderPrefs(snoozeEnabled: false, snoozeMinutes: 5),
            );
        clearInteractions(channel);
        final r = await c.read(prayerReminderServiceProvider).sync();

        expect(r, isA<ReminderSyncScheduled>());
        final entries = pushed();
        expect(entries.map((e) => e.prayerName), ['asr', 'maghrib', 'isha']);
        expect(entries.first.label, contains('Asr'));
        expect(entries.first.snoozeEnabled, isFalse);
        expect(entries.first.snoozeMinutes, 5);
        expect(entries[1].snoozeEnabled, isTrue);
        final times = entries.map((e) => e.triggerAt).toList();
        expect(times, [...times]..sort());
      },
    );

    test('drops prayers beyond the 7-day horizon', () async {
      final now = DateTime.now();
      giveDays([
        dayFromNow([1, 2, 3, 4, 5]),
        dayFromNow([1, 2, 3, 4, 5], base: now.add(const Duration(days: 8))),
      ]);
      stubPush(5);
      await make().read(prayerReminderServiceProvider).sync();
      expect(pushed(), hasLength(5));
    });

    test('disabled prayers are skipped', () async {
      giveDays([
        dayFromNow([1, 2, 3, 4, 5]),
      ]);
      stubPush(4);
      final c = make();
      stubPush(4);
      await c
          .read(prayerReminderPrefsProvider.notifier)
          .update(PrayerName.fajr, const PrayerReminderPrefs(enabled: false));
      clearInteractions(channel);
      await c.read(prayerReminderServiceProvider).sync();
      expect(pushed().map((e) => e.prayerName), isNot(contains('fajr')));
    });

    test('every prayer off cancels all and reports 0 armed', () async {
      giveDays([
        dayFromNow([1, 2, 3, 4, 5]),
      ]);
      final c = make();
      stubPush(5);
      await c.read(prayerReminderPrefsProvider.notifier).setAllEnabled(false);
      clearInteractions(channel);
      final r = await c.read(prayerReminderServiceProvider).sync();
      expect(r, isA<ReminderSyncScheduled>());
      expect((r as ReminderSyncScheduled).alarmCount, 0);
      verify(() => channel.cancelAll()).called(1);
      verifyNever(
        () => channel.pushSchedule(
          any(),
          snoozeMinutes: any(named: 'snoozeMinutes'),
        ),
      );
    });

    test(
      'nothing upcoming (all in the past) -> failed with explanation',
      () async {
        giveDays([
          dayFromNow([-5, -4, -3, -2, -1]),
        ]);
        final r = await make().read(prayerReminderServiceProvider).sync();
        expect(r, isA<ReminderSyncFailed>());
        expect((r as ReminderSyncFailed).message, contains('upcoming prayer'));
      },
    );

    test('native returns null -> "not available" failure', () async {
      giveDays([
        dayFromNow([1, 2, 3, 4, 5]),
      ]);
      stubPush(null);
      final r = await make().read(prayerReminderServiceProvider).sync();
      expect(r, isA<ReminderSyncFailed>());
      expect((r as ReminderSyncFailed).message, contains('not available'));
    });

    test(
      'prayer-time load failure is surfaced and nothing is pushed',
      () async {
        // no months configured -> NetworkFailure, no cache
        final r = await make().read(prayerReminderServiceProvider).sync();
        expect(r, isA<ReminderSyncFailed>());
        expect(
          (r as ReminderSyncFailed).message,
          const NetworkFailure().message,
        );
        verifyNever(
          () => channel.pushSchedule(
            any(),
            snoozeMinutes: any(named: 'snoozeMinutes'),
          ),
        );
      },
    );

    test('dayCount counts distinct calendar days', () async {
      final now = DateTime.now();
      giveDays([
        dayFromNow([1, 2, 3, 4, 5]),
        dayFromNow([1, 2, 3, 4, 5], base: now.add(const Duration(days: 2))),
      ]);
      stubPush(10);
      final r = await make().read(prayerReminderServiceProvider).sync();
      final s = r as ReminderSyncScheduled;
      expect(s.alarmCount, 10);
      expect(s.dayCount, greaterThanOrEqualTo(2));
    });

    test('cancelAll delegates to the channel', () async {
      await make().read(prayerReminderServiceProvider).cancelAll();
      verify(() => channel.cancelAll()).called(1);
    });
  });

  group('PrayerReminderPrefsNotifier', () {
    void giveDays() {
      for (var m = 1; m <= 12; m++) {
        repo.months[m] = Success([
          dayFromNow([1, 2, 3, 4, 5]),
        ]);
      }
    }

    test('loads persisted prefs', () {
      storage.boxes[AppConstants.settingsBoxName] = {
        AppConstants.prayerReminderPrefsKey: encodePrayerPrefs(
          defaultPrayerPrefs()
            ..[PrayerName.isha] = const PrayerReminderPrefs(enabled: false),
        ),
      };
      final c = make();
      expect(
        c.read(prayerReminderPrefsProvider)[PrayerName.isha]!.enabled,
        isFalse,
      );
      expect(
        c.read(prayerReminderPrefsProvider)[PrayerName.fajr]!.enabled,
        isTrue,
      );
    });

    test('master switch off: persists, no native call, state Idle', () async {
      final c = make();
      await c
          .read(prayerReminderPrefsProvider.notifier)
          .update(
            PrayerName.dhuhr,
            const PrayerReminderPrefs(snoozeMinutes: 20),
          );
      expect(
        c.read(prayerReminderPrefsProvider)[PrayerName.dhuhr]!.snoozeMinutes,
        20,
      );
      expect(c.read(reminderApplyProvider), isA<ReminderIdle>());
      expect(
        decodePrayerPrefs(
          storage.boxes[AppConstants.settingsBoxName]![AppConstants
                  .prayerReminderPrefsKey]
              as String,
        )[PrayerName.dhuhr]!.snoozeMinutes,
        20,
      );
      verifyNever(
        () => channel.pushSchedule(
          any(),
          snoozeMinutes: any(named: 'snoozeMinutes'),
        ),
      );
    });

    test('master on + native confirms: Applied with summary', () async {
      giveDays();
      stubPush(5);
      final c = make();
      await c.read(remindersEnabledProvider.notifier).set(true);
      await c
          .read(prayerReminderPrefsProvider.notifier)
          .update(PrayerName.fajr, const PrayerReminderPrefs(snoozeMinutes: 5));
      final s = c.read(reminderApplyProvider);
      expect(s, isA<ReminderApplied>());
      expect((s as ReminderApplied).message, startsWith('Saved'));
      expect(
        c.read(prayerReminderPrefsProvider)[PrayerName.fajr]!.snoozeMinutes,
        5,
      );
    });

    test(
      'master on + native fails: change rolled back in state AND storage',
      () async {
        giveDays();
        stubPush(null);
        final c = make();
        await c.read(remindersEnabledProvider.notifier).set(true);
        await c
            .read(prayerReminderPrefsProvider.notifier)
            .update(PrayerName.fajr, const PrayerReminderPrefs(enabled: false));
        expect(
          c.read(prayerReminderPrefsProvider)[PrayerName.fajr]!.enabled,
          isTrue,
        );
        expect(c.read(reminderApplyProvider), isA<ReminderApplyFailed>());
        final stored = decodePrayerPrefs(
          storage.boxes[AppConstants.settingsBoxName]![AppConstants
                  .prayerReminderPrefsKey]
              as String,
        );
        expect(stored[PrayerName.fajr]!.enabled, isTrue);
      },
    );

    test(
      'setAllEnabled(false) flips all five, keeping snooze settings',
      () async {
        final c = make();
        await c
            .read(prayerReminderPrefsProvider.notifier)
            .update(
              PrayerName.asr,
              const PrayerReminderPrefs(snoozeMinutes: 15),
            );
        await c.read(prayerReminderPrefsProvider.notifier).setAllEnabled(false);
        final prefs = c.read(prayerReminderPrefsProvider);
        expect(prefs.values.every((p) => !p.enabled), isTrue);
        expect(prefs[PrayerName.asr]!.snoozeMinutes, 15);
      },
    );
  });

  group('describeSync', () {
    test('scheduled / zero / failed / disabled', () {
      expect(
        describeSync(const ReminderSyncScheduled(35, 7)),
        'Saved · 35 alarms armed for the next 7 days.',
      );
      expect(
        describeSync(const ReminderSyncScheduled(0, 0)),
        contains('No prayers selected'),
      );
      expect(describeSync(const ReminderSyncFailed('nope')), 'nope');
      expect(describeSync(const ReminderSyncDisabled()), 'Reminders are off.');
    });
  });
}
