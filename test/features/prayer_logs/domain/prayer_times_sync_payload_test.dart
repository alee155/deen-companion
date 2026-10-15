import 'package:deen_companion/features/prayer_logs/domain/prayer_times_sync_payload.dart';
import 'package:deen_companion/features/prayer_times/domain/entities/prayer_times.dart';
import 'package:flutter_test/flutter_test.dart';

PrayerTimes _day(int d, {int asrHour = 15}) => PrayerTimes(
  fajr: DateTime(2026, 10, d, 4, 51),
  sunrise: DateTime(2026, 10, d, 6, 8),
  dhuhr: DateTime(2026, 10, d, 12, 5),
  asr: DateTime(2026, 10, d, asrHour, 20),
  maghrib: DateTime(2026, 10, d, 18, 2),
  isha: DateTime(2026, 10, d, 19, 20),
  hijriDate: 'h',
);

void main() {
  final now = DateTime(2026, 10, 13, 9);

  test('keeps only today..today+7, ordered, one per date', () {
    final out = PrayerTimesSyncPayload.build([
      _day(25),
      _day(12),
      _day(14),
      _day(13),
      _day(13),
      _day(20),
      _day(21),
    ], now);
    expect(out.map((d) => d['date']), [
      '2026-10-13',
      '2026-10-14',
      '2026-10-20',
    ]);
  });

  test('drops days without sunrise or with out-of-order times', () {
    final noSunrise = PrayerTimes(
      fajr: DateTime(2026, 10, 14, 4, 51),
      dhuhr: DateTime(2026, 10, 14, 12),
      asr: DateTime(2026, 10, 14, 15),
      maghrib: DateTime(2026, 10, 14, 18),
      isha: DateTime(2026, 10, 14, 19),
      hijriDate: 'h',
    );
    final out = PrayerTimesSyncPayload.build([
      _day(13),
      noSunrise,
      _day(15, asrHour: 11),
    ], now);
    expect(out.map((d) => d['date']), ['2026-10-13']);
  });

  test('formats times with the UTC offset', () {
    final out = PrayerTimesSyncPayload.build([_day(13)], now).single;
    final offset = DateTime(2026, 10, 13, 4, 51).timeZoneOffset;
    final sign = offset.isNegative ? '-' : '+';
    final hh = offset.abs().inHours.toString().padLeft(2, '0');
    final mm = (offset.abs().inMinutes % 60).toString().padLeft(2, '0');
    expect(out['fajr'], '2026-10-13T04:51:00$sign$hh:$mm');
    expect(out.keys, containsAll(['date', 'sunrise', 'isha']));
  });
}
