import 'package:deen_companion/core/theme/app_theme.dart';
import 'package:deen_companion/features/quran/domain/entities/juz.dart';
import 'package:deen_companion/features/quran/presentation/widgets/juz_verse_tile.dart';
import 'package:deen_companion/shared/providers/reading_preferences_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

const _english = 'In the name of Allah, the Entirely Merciful.';
const _urdu = 'اللہ کےنام سے جو رحمان و رحیم ہے';

JuzVerse _verse({Map<String, String>? translations}) => JuzVerse(
  verseKey: '1:1',
  surahName: 'Al-Fatihah',
  ayah: 1,
  arabic: 'بِسْمِ ٱللَّهِ',
  transliteration: 'Bismi',
  translations:
      translations ?? const {'sahih_international': _english, 'urdu': _urdu},
);

void main() {
  group('resolveTranslation', () {
    test('English by default', () {
      expect(resolveTranslation(_verse()), _english);
    });

    test('Urdu when chosen', () {
      expect(resolveTranslation(_verse(), TranslationLanguage.urdu), _urdu);
    });

    test('Urdu with no Urdu text is empty, never the English', () {
      final v = _verse(translations: const {'sahih_international': _english});
      expect(resolveTranslation(v, TranslationLanguage.urdu), '');
    });

    test('a blank Urdu entry is also empty', () {
      final v = _verse(
        translations: const {'sahih_international': _english, 'urdu': '  '},
      );
      expect(resolveTranslation(v, TranslationLanguage.urdu), '');
    });
  });

  testWidgets('Urdu style is Nastaliq with tall leading; English is not', (
    tester,
  ) async {
    late ReadingPreferences en;
    late ReadingPreferences ur;
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(375, 812),
        builder: (context, child) {
          en = const ReadingPreferences();
          ur = const ReadingPreferences(
            translationLanguage: TranslationLanguage.urdu,
          );
          expect(ur.translationStyle.fontFamily, 'NotoNastaliqUrdu');
          expect(en.translationStyle.fontFamily, isNot('NotoNastaliqUrdu'));
          // Nastaliq stacks tall: it needs far more leading than Latin text.
          expect(ur.urduStyle.height, greaterThanOrEqualTo(2.0));
          return const SizedBox();
        },
      ),
    );
  });

  group('JuzVerseTile', () {
    Future<SelectableText> pumpTile(
      WidgetTester tester,
      ReadingPreferences prefs, {
      JuzVerse? verse,
    }) async {
      await tester.pumpWidget(
        ScreenUtilInit(
          designSize: const Size(375, 812),
          builder: (context, child) => MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              body: SingleChildScrollView(
                child: JuzVerseTile(
                  verse: verse ?? _verse(),
                  preferences: prefs,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // The translation is the second SelectableText (Arabic is the first).
      return tester
          .widgetList<SelectableText>(find.byType(SelectableText))
          .last;
    }

    testWidgets('English is unchanged: left-aligned, left-to-right', (
      tester,
    ) async {
      final t = await pumpTile(tester, const ReadingPreferences());
      expect(t.data, _english);
      expect(t.textAlign, TextAlign.left);
      expect(t.textDirection, TextDirection.ltr);
      expect(t.style?.fontFamily, isNot('NotoNastaliqUrdu'));
    });

    testWidgets('Urdu is right-to-left in the Nastaliq font', (tester) async {
      final t = await pumpTile(
        tester,
        const ReadingPreferences(translationLanguage: TranslationLanguage.urdu),
      );
      expect(t.data, _urdu);
      expect(t.textAlign, TextAlign.right);
      expect(t.textDirection, TextDirection.rtl);
      expect(t.style?.fontFamily, 'NotoNastaliqUrdu');
    });

    testWidgets('a verse without Urdu says so and shows no English', (
      tester,
    ) async {
      await tester.pumpWidget(
        ScreenUtilInit(
          designSize: const Size(375, 812),
          builder: (context, child) => MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              body: SingleChildScrollView(
                child: JuzVerseTile(
                  verse: _verse(
                    translations: const {'sahih_international': _english},
                  ),
                  preferences: const ReadingPreferences(
                    translationLanguage: TranslationLanguage.urdu,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Urdu translation is not available'), findsOneWidget);
      expect(find.text(_english), findsNothing);
    });
  });
}
