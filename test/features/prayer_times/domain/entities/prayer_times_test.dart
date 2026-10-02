import 'package:deen_companion/features/prayer_times/domain/entities/prayer_calculation_settings.dart';
import 'package:deen_companion/features/prayer_times/domain/entities/prayer_times.dart';
import 'package:flutter_test/flutter_test.dart';

PrayerTimes _day() => PrayerTimes(
  fajr: DateTime(2026, 9, 30, 5),
  dhuhr: DateTime(2026, 9, 30, 12, 30),
  asr: DateTime(2026, 9, 30, 16),
  maghrib: DateTime(2026, 9, 30, 19),
  isha: DateTime(2026, 9, 30, 20, 30),
  hijriDate: 'x',
);

void main() {
  group('PrayerTimes.nextPrayer', () {
    final t = _day();

    test('before Fajr -> Fajr', () {
      expect(t.nextPrayer(DateTime(2026, 9, 30, 3)).key, PrayerName.fajr);
    });

    test('between prayers picks the following one', () {
      expect(t.nextPrayer(DateTime(2026, 9, 30, 13)).key, PrayerName.asr);
      expect(t.nextPrayer(DateTime(2026, 9, 30, 17)).key, PrayerName.maghrib);
      expect(t.nextPrayer(DateTime(2026, 9, 30, 19, 30)).key, PrayerName.isha);
    });

    test('exactly at a prayer time that prayer is already past', () {
      final next = t.nextPrayer(DateTime(2026, 9, 30, 12, 30));
      expect(next.key, PrayerName.asr);
    });

    test('one second before a prayer still returns it', () {
      final next = t.nextPrayer(DateTime(2026, 9, 30, 12, 29, 59));
      expect(next.key, PrayerName.dhuhr);
    });

    test('after Isha wraps to tomorrow\'s Fajr (today + 1 day)', () {
      final next = t.nextPrayer(DateTime(2026, 9, 30, 23));
      expect(next.key, PrayerName.fajr);
      expect(next.value, DateTime(2026, 10, 1, 5));
    });

    test('exactly at Isha wraps as well', () {
      final next = t.nextPrayer(DateTime(2026, 9, 30, 20, 30));
      expect(next.value, DateTime(2026, 10, 1, 5));
    });
  });

  group('timeUntilNextPrayer', () {
    final t = _day();
    test('duration to the next prayer', () {
      expect(
        t.timeUntilNextPrayer(DateTime(2026, 9, 30, 11, 45)),
        const Duration(minutes: 45),
      );
    });

    test('after Isha counts across midnight to tomorrow Fajr', () {
      expect(
        t.timeUntilNextPrayer(DateTime(2026, 9, 30, 22)),
        const Duration(hours: 7),
      );
    });
  });

  test('value equality via Equatable', () {
    expect(_day(), _day());
    expect(
      _day() ==
          PrayerTimes(
            fajr: DateTime(2026, 9, 30, 5, 1),
            dhuhr: DateTime(2026, 9, 30, 12, 30),
            asr: DateTime(2026, 9, 30, 16),
            maghrib: DateTime(2026, 9, 30, 19),
            isha: DateTime(2026, 9, 30, 20, 30),
            hijriDate: 'x',
          ),
      isFalse,
    );
  });

  group('PrayerCalculationSettings', () {
    test('fallback is Muslim World League + Shafi', () {
      expect(
        PrayerCalculationSettings.fallback.method,
        PrayerCalculationMethod.muslimWorldLeague,
      );
      expect(PrayerCalculationSettings.fallback.school, AsrSchool.shafi);
    });

    test(
      'AlAdhan method ids match the API (MWL=3, Karachi=1, UmmAlQura=4)',
      () {
        expect(PrayerCalculationMethod.muslimWorldLeague.id, 3);
        expect(PrayerCalculationMethod.karachi.id, 1);
        expect(PrayerCalculationMethod.isna.id, 2);
        expect(PrayerCalculationMethod.ummAlQura.id, 4);
        expect(PrayerCalculationMethod.egyptian.id, 5);
        expect(PrayerCalculationMethod.tehran.id, 7);
      },
    );

    test('method ids are unique and id 6 is intentionally unused', () {
      final ids = PrayerCalculationMethod.values.map((m) => m.id).toList();
      expect(ids.toSet().length, ids.length);
      expect(ids, isNot(contains(6)));
    });

    test('asr school ids: Shafi 0, Hanafi 1', () {
      expect(AsrSchool.shafi.id, 0);
      expect(AsrSchool.hanafi.id, 1);
    });

    test('copyWith overrides only the given field', () {
      const s = PrayerCalculationSettings.fallback;
      final a = s.copyWith(school: AsrSchool.hanafi);
      expect(a.method, s.method);
      expect(a.school, AsrSchool.hanafi);
      final b = s.copyWith(method: PrayerCalculationMethod.karachi);
      expect(b.school, s.school);
      expect(b.method, PrayerCalculationMethod.karachi);
      expect(s.copyWith().method, s.method);
    });
  });
}
