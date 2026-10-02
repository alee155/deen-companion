import 'package:deen_companion/shared/providers/reading_preferences_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:deen_companion/core/theme/app_theme.dart';
import 'package:deen_companion/features/hadith/data/models/hadith_model.dart';
import 'package:deen_companion/features/hadith/domain/entities/hadith.dart';
import 'package:deen_companion/features/hadith/domain/hadith_cover_assets.dart';
import 'package:deen_companion/features/hadith/domain/hadith_grade.dart';

import 'package:deen_companion/features/hadith/presentation/widgets/hadith_reader_page.dart';

Hadith _hadith({
  String english = 'The reward of deeds…',
  String arabic = 'إنما',
}) {
  return Hadith(
    id: 'bukhari:1',
    collection: 'bukhari',
    collectionName: 'Sahih al-Bukhari',
    hadithNumber: 1,
    arabic: arabic,
    english: english,
    grade: 'Sahih',
  );
}

void main() {
  group('HadithModel.fromJson resilience', () {
    // The upstream dataset is not uniformly populated; a single malformed
    // record used to throw and fail the whole 50-hadith page.
    test('survives a missing English translation', () {
      final model = HadithModel.fromJson({
        'id': 'bukhari:5710',
        'collection': 'bukhari',
        'collection_name': 'Sahih al-Bukhari',
        'hadithnumber': 5710,
        'arabic': 'نص عربي',
        'english': null,
        'grade': 'Sahih',
      });

      expect(model.english, '');
      expect(model.toEntity().hasTranslation, isFalse);
      expect(model.toEntity().hasArabic, isTrue);
    });

    test('survives entirely absent fields', () {
      final model = HadithModel.fromJson({'id': 'x'});
      expect(model.english, '');
      expect(model.arabic, '');
      expect(model.hadithNumber, 0);
    });

    test('accepts a decimal hadith number (sub-narrations like 402.2)', () {
      final model = HadithModel.fromJson({
        'id': 'bukhari:402.2',
        'hadithnumber': 402.2,
      });
      expect(model.hadithNumber, 402);
    });

    test('accepts a hadith number sent as a string', () {
      expect(HadithModel.fromJson({'hadithnumber': '77'}).hadithNumber, 77);
      expect(HadithModel.fromJson({'hadithnumber': 'n/a'}).hadithNumber, 0);
    });

    test('round-trips through the cache without losing text', () {
      final original = _hadith(english: 'A' * 4000);
      final restored = HadithModel.fromJson(
        HadithModel(
          id: original.id,
          collection: original.collection,
          collectionName: original.collectionName,
          hadithNumber: original.hadithNumber,
          arabic: original.arabic,
          english: original.english,
          grade: original.grade,
        ).toJson(),
      );
      // Long translations must not be trimmed anywhere in the pipeline.
      expect(restored.english.length, 4000);
    });
  });

  group('HadithGrade', () {
    test('reads the common gradings, including a named grader', () {
      expect(HadithGrade.parse('Sahih'), HadithGrade.sahih);
      expect(HadithGrade.parse('Sahih (Al-Albani)'), HadithGrade.sahih);
      expect(HadithGrade.parse('Hasan'), HadithGrade.hasan);
      expect(HadithGrade.parse("Da'if"), HadithGrade.daif);
      expect(HadithGrade.parse('Weak'), HadithGrade.daif);
    });

    test('falls back to Ungraded for blank or unfamiliar values', () {
      expect(HadithGrade.parse(null), HadithGrade.unknown);
      expect(HadithGrade.parse('Various'), HadithGrade.unknown);
    });

    test('does not mistake a weak narration for an authentic one', () {
      expect(HadithGrade.parse("Da'if"), isNot(HadithGrade.sahih));
    });
  });

  group('Hadith share text', () {
    test('always carries the reference', () {
      final text = _hadith().toShareText();
      expect(text, contains('Sahih al-Bukhari'));
      expect(text, contains('Hadith 1'));
    });

    test('omits an absent translation instead of leaving a blank block', () {
      final text = _hadith(english: '   ').toShareText();
      expect(text, isNot(contains('   \n')));
      expect(text, contains('إنما'));
    });
  });

  group('ReadingPreferences', () {
    testWidgets('scales the two scripts independently', (tester) async {
      await tester.pumpWidget(
        ScreenUtilInit(
          designSize: const Size(375, 812),
          builder: (context, child) {
            const prefs = ReadingPreferences(
              arabicScale: 1.5,
              englishScale: 1.0,
            );
            final base = const ReadingPreferences();

            expect(
              prefs.arabicStyle.fontSize,
              greaterThan(base.arabicStyle.fontSize!),
            );
            expect(prefs.englishStyle.fontSize, base.englishStyle.fontSize);

            // Arabic needs the taller line box for its diacritics.
            expect(
              prefs.arabicStyle.height!,
              greaterThan(prefs.englishStyle.height!),
            );
            return const SizedBox.shrink();
          },
        ),
      );
    });

    test('reports whether it differs from the defaults', () {
      expect(const ReadingPreferences().isDefault, isTrue);
      expect(const ReadingPreferences(arabicScale: 1.3).isDefault, isFalse);
    });

    test('labels the scale as a percentage', () {
      expect(const ReadingPreferences(arabicScale: 1.25).arabicLabel, '125%');
    });
  });

  group('HadithReaderPage rendering', () {
    Future<void> pumpPage(WidgetTester tester, Hadith hadith) async {
      await tester.pumpWidget(
        ScreenUtilInit(
          designSize: const Size(375, 812),
          builder: (context, child) => MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              body: HadithReaderPage(
                hadith: hadith,
                collection: null,
                preferences: const ReadingPreferences(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('renders a long translation in full, with no line limit', (
      tester,
    ) async {
      // Longest Bukhari translation in the source data is ~8.8k characters.
      final long = List.filled(400, 'the reward of deeds').join(' ');
      await pumpPage(tester, _hadith(english: long));

      final texts = tester
          .widgetList<SelectableText>(find.byType(SelectableText))
          .toList();
      final translation = texts.firstWhere((t) => t.data == long);

      expect(translation.data!.length, long.length);
      // maxLines must stay null — a limit here is exactly what would clip a
      // long translation mid-sentence.
      expect(translation.maxLines, isNull);
    });

    testWidgets('says so when the source has no translation', (tester) async {
      await pumpPage(tester, _hadith(english: ''));

      expect(
        find.textContaining('No English translation is available'),
        findsOneWidget,
      );
    });

    testWidgets('hides a block the reader switched off', (tester) async {
      await tester.pumpWidget(
        ScreenUtilInit(
          designSize: const Size(375, 812),
          builder: (context, child) => MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              body: HadithReaderPage(
                hadith: _hadith(),
                collection: null,
                preferences: const ReadingPreferences(showArabic: false),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final rendered = tester
          .widgetList<SelectableText>(find.byType(SelectableText))
          .map((t) => t.data)
          .toList();
      expect(rendered, contains('The reward of deeds…'));
      expect(rendered, isNot(contains('إنما')));
    });
  });

  group('HadithCoverAssets', () {
    test('returns null rather than a non-existent default asset', () {
      // The three 40-hadith collections have no artwork; pointing them at a
      // missing default.png is what produced a broken image box.
      expect(HadithCoverAssets.forKey('nawawi'), isNull);
      expect(HadithCoverAssets.forKey('qudsi'), isNull);
      expect(HadithCoverAssets.forKey('dehlawi'), isNull);
      expect(HadithCoverAssets.hasCover('nawawi'), isFalse);
    });

    test('maps every collection that does have artwork', () {
      for (final key in [
        'bukhari',
        'muslim',
        'abudawud',
        'tirmidhi',
        'ibnmajah',
        'nasai',
        'malik',
      ]) {
        expect(HadithCoverAssets.forKey(key), isNotNull, reason: key);
      }
    });
  });
}
