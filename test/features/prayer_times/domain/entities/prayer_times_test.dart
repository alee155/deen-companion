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
  wallClockAndNextFajrTests();
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

void wallClockAndNextFajrTests() {
  group('server-backed times', () {
    // 04:44 PKT on 14 Oct is 23:44 UTC on the 13th.
    PrayerTimes pk({Duration? offset = const Duration(hours: 5)}) =>
        PrayerTimes(
          fajr: DateTime.utc(2026, 10, 13, 23, 44),
          dhuhr: DateTime.utc(2026, 10, 14, 6, 49),
          asr: DateTime.utc(2026, 10, 14, 10, 54),
          maghrib: DateTime.utc(2026, 10, 14, 12, 32),
          isha: DateTime.utc(2026, 10, 14, 13, 53),
          hijriDate: '3 Jumādá al-ūlá 1448 AH',
          utcOffset: offset,
        );

    test('wallClock shows the prayer location\'s clock, not the phone\'s', () {
      final t = pk();
      final fajr = t.wallClock(t.fajr);
      expect((fajr.hour, fajr.minute), (4, 44));
      expect(fajr.day, 14, reason: 'the local date, not the UTC date');
      final asr = t.wallClock(t.asr);
      expect((asr.hour, asr.minute), (15, 54));
    });

    test('a half-hour offset is respected', () {
      final t = pk(offset: const Duration(hours: 5, minutes: 30));
      final isha = t.wallClock(t.isha);
      expect((isha.hour, isha.minute), (19, 23));
    });

    test('without an offset it falls back to the device zone', () {
      final local = DateTime(2026, 10, 14, 4, 44);
      final t = PrayerTimes(
        fajr: local,
        dhuhr: DateTime(2026, 10, 14, 12),
        asr: DateTime(2026, 10, 14, 15),
        maghrib: DateTime(2026, 10, 14, 18),
        isha: DateTime(2026, 10, 14, 19),
        hijriDate: '',
      );
      expect(t.wallClock(local), local);
    });

    test('after Isha the next prayer is the real next-day Fajr', () {
      final tomorrowFajr = DateTime.utc(2026, 10, 14, 23, 45);
      final t = PrayerTimes(
        fajr: DateTime.utc(2026, 10, 13, 23, 44),
        dhuhr: DateTime.utc(2026, 10, 14, 6, 49),
        asr: DateTime.utc(2026, 10, 14, 10, 54),
        maghrib: DateTime.utc(2026, 10, 14, 12, 32),
        isha: DateTime.utc(2026, 10, 14, 13, 53),
        hijriDate: '',
        nextFajr: tomorrowFajr,
      );
      final next = t.nextPrayer(DateTime.utc(2026, 10, 14, 15));
      expect(next.key, PrayerName.fajr);
      expect(next.value, tomorrowFajr, reason: 'not today\'s Fajr + 24 h');
    });

    test('without a known next Fajr it keeps the 24 hour estimate', () {
      final t = pk();
      final next = t.nextPrayer(DateTime.utc(2026, 10, 14, 15));
      expect(next.value, t.fajr.add(const Duration(days: 1)));
    });
  });
}
