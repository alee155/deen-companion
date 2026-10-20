import 'package:deen_companion/features/prayer_times/domain/entities/prayer_times.dart';
import 'package:deen_companion/features/theme/domain/theme_schedule.dart';
import 'package:flutter_test/flutter_test.dart';

DateTime t(int h, [int m = 0, int day = 10]) => DateTime(2026, 6, day, h, m);

PrayerTimes times({
  DateTime? sunrise,
  bool withSunrise = true,
  DateTime? nextFajr,
  DateTime? isha,
}) => PrayerTimes(
  fajr: t(4, 0),
  sunrise: withSunrise ? (sunrise ?? t(5, 30)) : null,
  dhuhr: t(12, 30),
  asr: t(16, 0),
  maghrib: t(19, 30),
  isha: isha ?? t(21, 0),
  hijriDate: '',
  nextFajr: nextFajr ?? t(4, 1, 11),
);

void main() {
  group('periodAt with server times', () {
    final s = ThemeSchedule.fromPrayerTimes(times(), t(10))!;

    test('walks through every period of the day', () {
      expect(s.periodAt(t(2)), ThemePeriod.isha); // after midnight, pre-Fajr
      expect(s.periodAt(t(4)), ThemePeriod.fajr); // boundary is inclusive
      expect(s.periodAt(t(5, 29)), ThemePeriod.fajr);
      expect(s.periodAt(t(5, 30)), ThemePeriod.sunrise);
      expect(s.periodAt(t(6, 59)), ThemePeriod.sunrise);
      expect(s.periodAt(t(7, 0)), ThemePeriod.dhuhr); // sunrise + 90 min
      expect(s.periodAt(t(15, 59)), ThemePeriod.dhuhr);
      expect(s.periodAt(t(16)), ThemePeriod.asr);
      expect(s.periodAt(t(19, 30)), ThemePeriod.maghrib);
      expect(s.periodAt(t(20, 14)), ThemePeriod.maghrib);
      expect(s.periodAt(t(20, 15)), ThemePeriod.isha); // maghrib + 45 min
      expect(s.periodAt(t(23, 59)), ThemePeriod.isha);
    });

    test('Isha starts earlier when the Isha prayer is sooner than +45 min', () {
      final early = ThemeSchedule.fromPrayerTimes(
        times(isha: t(19, 50)),
        t(10),
      )!;
      expect(early.periodAt(t(19, 49)), ThemePeriod.maghrib);
      expect(early.periodAt(t(19, 50)), ThemePeriod.isha);
    });

    test('Dhuhr look starts at Dhuhr when sunrise window would overrun it', () {
      final late = ThemeSchedule.fromPrayerTimes(
        times(sunrise: t(11, 30)),
        t(10),
      )!;
      expect(late.periodAt(t(12, 29)), ThemePeriod.sunrise);
      expect(late.periodAt(t(12, 30)), ThemePeriod.dhuhr);
    });

    test('nextChangeAfter finds the next boundary, then the next Fajr', () {
      expect(s.nextChangeAfter(t(10)), t(16));
      expect(s.nextChangeAfter(t(21)), t(4, 1, 11));
      expect(s.nextChangeAfter(t(5)), t(5, 30));
      expect(s.nextChangeAfter(t(4, 1, 11)), isNull);
    });
  });

  group('edge cases', () {
    test('missing sunrise folds Sunrise into Fajr', () {
      final s = ThemeSchedule.fromPrayerTimes(
        times(withSunrise: false),
        t(10),
      )!;
      expect(s.periodAt(t(6)), ThemePeriod.fajr);
      expect(s.periodAt(t(12, 30)), ThemePeriod.dhuhr);
    });

    test('times for another day are not trusted', () {
      expect(ThemeSchedule.fromPrayerTimes(times(), t(10, 0, 12)), isNull);
      expect(ThemeSchedule.fromPrayerTimes(times(), t(10, 0, 8)), isNull);
    });

    test('out-of-order times are not trusted', () {
      final bad = times(sunrise: t(3)); // sunrise before Fajr
      expect(ThemeSchedule.fromPrayerTimes(bad, t(10)), isNull);
    });

    test('just after midnight uses yesterday\'s schedule as Isha', () {
      final s = ThemeSchedule.fromPrayerTimes(times(), t(0, 30, 11))!;
      expect(s.periodAt(t(0, 30, 11)), ThemePeriod.isha);
    });

    test('no prayer times falls back to the approximate day', () {
      final s = ThemeSchedule.forNow(null, t(13));
      expect(s.periodAt(t(13)), ThemePeriod.dhuhr);
      expect(s.periodAt(t(2)), ThemePeriod.isha);
      expect(s.periodAt(t(22)), ThemePeriod.isha);
    });

    test('unusable times also fall back', () {
      final s = ThemeSchedule.forNow(times(), t(10, 0, 20));
      expect(s.periodAt(t(10, 0, 20)), ThemePeriod.dhuhr);
    });
  });
}
