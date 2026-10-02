import 'package:deen_companion/features/daily_content/domain/daily_content_selector.dart';
import 'package:deen_companion/features/daily_content/domain/daily_notification_config.dart';
import 'package:deen_companion/features/daily_content/domain/entities/daily_content.dart';
import 'package:deen_companion/features/daily_content/domain/notification_text.dart';
import 'package:deen_companion/features/hadith/domain/entities/hadith.dart';
import 'package:flutter_test/flutter_test.dart';

DailyAyah ayah({String translation = 'In the name of God.'}) => DailyAyah(
  surahNumber: 2,
  surahNameEnglish: 'Al-Baqarah',
  surahNameArabic: 'البقرة',
  ayahNumber: 255,
  arabic: 'آية',
  translation: translation,
);

const hadith = Hadith(
  id: 'nawawi:1',
  collection: 'nawawi',
  collectionName: 'Forty Hadith',
  hadithNumber: 7,
  arabic: 'ar',
  english: 'en',
  grade: 'Sahih',
);

void main() {
  group('DailyContentSelector', () {
    test('is deterministic and ignores time of day', () {
      final a = DailyContentSelector.ayahFor(DateTime(2025, 6, 1, 0, 0));
      final b = DailyContentSelector.ayahFor(DateTime(2025, 6, 1, 23, 59));
      expect(a, b);
      expect(
        DailyContentSelector.hadithNumberFor(DateTime(2025, 6, 1, 1)),
        DailyContentSelector.hadithNumberFor(DateTime(2025, 6, 1, 22)),
      );
    });

    test('epoch day 2024-01-01 maps to first verse and hadith 1', () {
      final d = DateTime(2024, 1, 1);
      expect(DailyContentSelector.ayahFor(d), (2, 255));
      expect(DailyContentSelector.hadithNumberFor(d), 1);
    });

    test('consecutive days advance the verse', () {
      expect(DailyContentSelector.ayahFor(DateTime(2024, 1, 2)), (2, 286));
      expect(DailyContentSelector.hadithNumberFor(DateTime(2024, 1, 2)), 2);
    });

    test('hadith number always within 1..42 over several years', () {
      var d = DateTime(2024, 1, 1);
      for (var i = 0; i < 1500; i++) {
        final n = DailyContentSelector.hadithNumberFor(d);
        expect(n, inInclusiveRange(1, 42));
        d = d.add(const Duration(days: 1));
      }
    });

    test('hadith wraps after 42 days', () {
      final d = DateTime(2024, 1, 1);
      expect(
        DailyContentSelector.hadithNumberFor(d.add(const Duration(days: 42))),
        1,
      );
      expect(
        DailyContentSelector.hadithNumberFor(d.add(const Duration(days: 41))),
        42,
      );
    });

    test('verse list cycles and every verse is valid for the Quran', () {
      final seen = <(int, int)>{};
      var d = DateTime(2024, 1, 1);
      for (var i = 0; i < 400; i++) {
        final v = DailyContentSelector.ayahFor(d);
        expect(v.$1, inInclusiveRange(1, 114));
        expect(v.$2, greaterThanOrEqualTo(1));
        seen.add(v);
        d = d.add(const Duration(days: 1));
      }
      // A rotation, not a constant.
      expect(seen.length, greaterThan(50));
    });

    test('dates before the epoch still yield valid (non-negative) indices', () {
      final v = DailyContentSelector.ayahFor(DateTime(2023, 6, 15));
      expect(v.$1, inInclusiveRange(1, 114));
      expect(
        DailyContentSelector.hadithNumberFor(DateTime(2023, 6, 15)),
        inInclusiveRange(1, 42),
      );
    });

    test('is not thrown off by DST transitions', () {
      // Local-time dates around typical DST changes: day index must still
      // advance by exactly one per calendar day.
      for (final start in [DateTime(2025, 3, 8), DateTime(2025, 10, 25)]) {
        final a = DailyContentSelector.hadithNumberFor(start);
        final b = DailyContentSelector.hadithNumberFor(
          DateTime(start.year, start.month, start.day + 1),
        );
        expect(b, a % 42 + 1);
      }
    });

    test('collection is nawawi', () {
      expect(DailyContentSelector.hadithCollection, 'nawawi');
    });

    group('dateKey / parseDateKey', () {
      test('zero-pads', () {
        expect(
          DailyContentSelector.dateKey(DateTime(2025, 3, 7)),
          '2025-03-07',
        );
        expect(DailyContentSelector.dateKey(DateTime(987, 1, 2)), '0987-01-02');
      });

      test('round trips', () {
        final d = DateTime(2026, 12, 31);
        final parsed = DailyContentSelector.parseDateKey(
          DailyContentSelector.dateKey(d),
        );
        expect(parsed, d);
      });

      test('rejects non yyyy-MM-dd input', () {
        for (final bad in [
          '',
          '2025-3-7',
          '20250307',
          'debug-1234',
          '2025-03-07T10:00',
          ' 2025-03-07',
          'abcd-ef-gh',
        ]) {
          expect(DailyContentSelector.parseDateKey(bad), isNull, reason: bad);
        }
      });
    });
  });

  group('DailyNotificationConfig', () {
    test('production values', () {
      const c = DailyNotificationConfig.production;
      expect(c.offsetAfterFajr, const Duration(minutes: 20));
      expect(c.windowDays, 7);
      expect(c.title, isNotEmpty);
    });
  });

  group('DailyAyah', () {
    test('verseKey / reference / share text', () {
      final a = ayah();
      expect(a.verseKey, '2:255');
      expect(a.reference, 'Surah Al-Baqarah · 2:255');
      expect(
        a.toShareText(),
        'آية\n\nIn the name of God.\n\n— Surah Al-Baqarah · 2:255',
      );
    });

    test('JSON round trip', () {
      final a = ayah();
      final b = DailyAyah.fromJson(a.toJson());
      expect(b.toJson(), a.toJson());
      expect(b.surahNumber, 2);
      expect(b.surahNameArabic, 'البقرة');
    });

    test('fromJson with missing/mistyped fields throws', () {
      expect(() => DailyAyah.fromJson({}), throwsA(isA<TypeError>()));
      final j = ayah().toJson()..['surah'] = '2';
      expect(() => DailyAyah.fromJson(j), throwsA(isA<TypeError>()));
    });
  });

  group('DailyNotificationText.preview', () {
    DailyContent content(String translation) => DailyContent(
      dateKey: '2025-01-01',
      ayah: ayah(translation: translation),
      hadith: hadith,
    );

    test('null content falls back to generic text', () {
      expect(
        DailyNotificationText.preview(null),
        DailyNotificationText.fallback,
      );
    });

    test('short translation is quoted with reference and hadith line', () {
      expect(
        DailyNotificationText.preview(content('Be patient.')),
        '“Be patient.” — 2:255\nHadith: Forty Hadith, #7',
      );
    });

    test('collapses whitespace and trims', () {
      final p = DailyNotificationText.preview(content('  a \n\n b\t c  '));
      expect(p.split('\n').first, '“a b c” — 2:255');
    });

    test('exactly 90 chars is not clipped', () {
      final t = 'x' * 90;
      expect(DailyNotificationText.preview(content(t)), contains('“$t”'));
    });

    test('over 90 chars is clipped with ellipsis', () {
      final t = 'y' * 91;
      final p = DailyNotificationText.preview(content(t));
      expect(p, contains('“${'y' * 90}…”'));
    });

    test('clip trims trailing space before the ellipsis', () {
      final t = '${'a' * 89} bbbbb';
      final p = DailyNotificationText.preview(content(t));
      expect(p, contains('“${'a' * 89}…”'));
    });

    test('empty translation yields empty quotes without crashing', () {
      expect(
        DailyNotificationText.preview(content('')),
        startsWith('“” — 2:255'),
      );
    });
  });
}
