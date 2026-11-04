import 'package:deen_companion/features/home/domain/prayer_day_progress.dart';
import 'package:deen_companion/features/prayer_times/domain/entities/prayer_times.dart';
import 'package:flutter_test/flutter_test.dart';

DateTime d(int h, [int m = 0, int day = 10]) => DateTime(2026, 6, day, h, m);

final _times = PrayerTimes(
  fajr: d(4),
  dhuhr: d(12, 30),
  asr: d(16),
  maghrib: d(19, 30),
  isha: d(21),
  hijriDate: '',
  nextFajr: d(4, 1, 11),
);

void main() {
  test('points at the next prayer and how long until it', () {
    final p = PrayerDayProgress.of(_times, d(10));
    expect(p.next, PrayerName.dhuhr);
    expect(p.nextAt, d(12, 30));
    expect(p.remaining, const Duration(hours: 2, minutes: 30));
  });

  test('after Isha the next prayer is tomorrow\'s Fajr', () {
    final p = PrayerDayProgress.of(_times, d(22));
    expect(p.next, PrayerName.fajr);
    expect(p.nextAt, d(4, 1, 11));
  });

  test('imminent within ten minutes, not before', () {
    expect(PrayerDayProgress.of(_times, d(12, 20)).isImminent, isTrue);
    expect(PrayerDayProgress.of(_times, d(12, 30)).isImminent, isFalse);
    expect(
      PrayerDayProgress.of(
        _times,
        DateTime(2026, 6, 10, 12, 19, 59),
      ).isImminent,
      isFalse,
    );
  });

  test('equal inputs give equal values', () {
    expect(
      PrayerDayProgress.of(_times, d(10)),
      PrayerDayProgress.of(_times, d(10)),
    );
  });
}
