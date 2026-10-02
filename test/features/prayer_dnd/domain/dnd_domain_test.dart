import 'package:deen_companion/features/prayer_dnd/domain/dnd_settings.dart';
import 'package:deen_companion/features/prayer_dnd/domain/dnd_window.dart';
import 'package:deen_companion/features/prayer_dnd/domain/dnd_window_planner.dart';
import 'package:deen_companion/features/prayer_times/domain/entities/prayer_times.dart';
import 'package:flutter_test/flutter_test.dart';

PrayerTimes _day(DateTime d, {int fajrHour = 5, int ishaHour = 20}) =>
    PrayerTimes(
      fajr: DateTime(d.year, d.month, d.day, fajrHour),
      dhuhr: DateTime(d.year, d.month, d.day, 12, 30),
      asr: DateTime(d.year, d.month, d.day, 16),
      maghrib: DateTime(d.year, d.month, d.day, 19),
      isha: DateTime(d.year, d.month, d.day, ishaHour, 30),
      hijriDate: '',
    );

void main() {
  group('DndSettings', () {
    test('defaults: disabled, preset mode, nothing configured', () {
      const s = DndSettings();
      expect(s.enabled, isFalse);
      expect(s.mode, DndDurationMode.preset);
      expect(s.configuredCount, 0);
      expect(s.minutesFor(PrayerName.fajr), isNull);
      expect(s.isConfigured(PrayerName.fajr), isFalse);
    });

    test('minutesFor / isConfigured / configuredCount reflect the map', () {
      const s = DndSettings(
        durations: {PrayerName.fajr: 15, PrayerName.isha: 45},
      );
      expect(s.minutesFor(PrayerName.isha), 45);
      expect(s.isConfigured(PrayerName.fajr), isTrue);
      expect(s.isConfigured(PrayerName.asr), isFalse);
      expect(s.configuredCount, 2);
    });

    test('copyWith overrides only given fields', () {
      const s = DndSettings(durations: {PrayerName.asr: 20});
      final a = s.copyWith(enabled: true);
      expect(a.enabled, isTrue);
      expect(a.durations, {PrayerName.asr: 20});
      final b = s.copyWith(mode: DndDurationMode.custom, durations: const {});
      expect(b.mode, DndDurationMode.custom);
      expect(b.configuredCount, 0);
    });

    test('preset list is within the custom min/max bounds', () {
      for (final m in DndSettings.presetMinutes) {
        expect(
          m,
          inInclusiveRange(
            DndSettings.minCustomMinutes,
            DndSettings.maxCustomMinutes,
          ),
        );
      }
      expect(DndSettings.defaultCustomMinutes, inInclusiveRange(1, 120));
    });
  });

  group('DndWindow.toMap', () {
    test('uses epoch milliseconds', () {
      final s = DateTime.utc(2026, 10, 1, 5);
      final w = DndWindow(
        prayerName: 'fajr',
        start: s,
        end: s.add(const Duration(minutes: 15)),
      );
      expect(w.toMap(), {
        'prayerName': 'fajr',
        'startMillis': s.millisecondsSinceEpoch,
        'endMillis': s.millisecondsSinceEpoch + 15 * 60 * 1000,
      });
    });
  });

  group('DndWindowPlanner', () {
    final now = DateTime(2026, 9, 30, 12);

    test('horizon is 28 days', () {
      expect(DndWindowPlanner.horizonDays, 28);
    });

    test('zero or negative minutes are ignored (corrupt settings)', () {
      final w = DndWindowPlanner.build(
        [_day(DateTime(2026, 10, 1))],
        const DndSettings(
          durations: {
            PrayerName.fajr: 0,
            PrayerName.dhuhr: -5,
            PrayerName.asr: 10,
          },
        ),
        now,
      );
      expect(w.map((e) => e.prayerName), ['asr']);
    });

    test('a prayer starting exactly now is excluded (strictly future)', () {
      final w = DndWindowPlanner.build(
        [_day(DateTime(2026, 9, 30))],
        const DndSettings(durations: {PrayerName.dhuhr: 10}),
        DateTime(2026, 9, 30, 12, 30),
      );
      expect(w, isEmpty);
    });

    test(
      'a prayer exactly on the horizon is included, one second later is not',
      () {
        final horizonStart = now.add(const Duration(days: 3));
        final onEdge = PrayerTimes(
          fajr: horizonStart,
          dhuhr: horizonStart.add(const Duration(seconds: 1)),
          asr: now,
          maghrib: now,
          isha: now,
          hijriDate: '',
        );
        final w = DndWindowPlanner.build(
          [onEdge],
          const DndSettings(
            durations: {PrayerName.fajr: 10, PrayerName.dhuhr: 10},
          ),
          now,
          windowDays: 3,
        );
        expect(w.map((e) => e.prayerName), ['fajr']);
      },
    );

    test('windows are sorted by start across unsorted input days', () {
      final w = DndWindowPlanner.build(
        [_day(DateTime(2026, 10, 2)), _day(DateTime(2026, 10, 1))],
        const DndSettings(durations: {PrayerName.fajr: 10}),
        now,
      );
      expect(w.map((e) => e.start.day), [1, 2]);
    });

    test('window may cross midnight (Isha late + long duration)', () {
      final w = DndWindowPlanner.build(
        [
          PrayerTimes(
            fajr: DateTime(2026, 10, 1, 5),
            dhuhr: DateTime(2026, 10, 1, 12),
            asr: DateTime(2026, 10, 1, 16),
            maghrib: DateTime(2026, 10, 1, 19),
            isha: DateTime(2026, 10, 1, 23, 30),
            hijriDate: '',
          ),
        ],
        const DndSettings(durations: {PrayerName.isha: 60}),
        now,
      );
      expect(w.single.end, DateTime(2026, 10, 2, 0, 30));
    });

    test('windowDays shorter than the data trims later days', () {
      final w = DndWindowPlanner.build(
        [_day(DateTime(2026, 10, 1)), _day(DateTime(2026, 10, 20))],
        const DndSettings(durations: {PrayerName.fajr: 10}),
        now,
        windowDays: 7,
      );
      expect(w, hasLength(1));
    });

    test('empty days list gives no windows', () {
      expect(
        DndWindowPlanner.build(
          const [],
          const DndSettings(durations: {PrayerName.fajr: 10}),
          now,
        ),
        isEmpty,
      );
    });

    test(
      'same-time duplicates are per prayer: different prayers at same minute both kept',
      () {
        final t = DateTime(2026, 10, 1, 12);
        final w = DndWindowPlanner.build(
          [
            PrayerTimes(
              fajr: DateTime(2026, 10, 1, 5),
              dhuhr: t,
              asr: t,
              maghrib: DateTime(2026, 10, 1, 19),
              isha: DateTime(2026, 10, 1, 20),
              hijriDate: '',
            ),
          ],
          const DndSettings(
            durations: {PrayerName.dhuhr: 10, PrayerName.asr: 10},
          ),
          now,
        );
        expect(w.map((e) => e.prayerName), containsAll(['dhuhr', 'asr']));
        expect(w, hasLength(2));
      },
    );
  });
}
