import 'package:deen_companion/features/quran/domain/entities/juz.dart';
import 'package:deen_companion/features/quran/domain/entities/mushaf_page.dart';
import 'package:deen_companion/features/quran/domain/entities/surah_summary.dart';
import 'package:deen_companion/features/quran/domain/juz_arabic_names.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('juzArabicName', () {
    test('has exactly 30 entries, all non-empty and unique', () {
      expect(juzArabicNames, hasLength(30));
      expect(juzArabicNames.every((n) => n.trim().isNotEmpty), isTrue);
      expect(juzArabicNames.toSet(), hasLength(30));
    });

    test('is 1-based', () {
      expect(juzArabicName(1), 'الم');
      expect(juzArabicName(30), 'عَمَّ يَتَسَاءَلُونَ');
    });

    test('out-of-range numbers throw RangeError', () {
      expect(() => juzArabicName(0), throwsRangeError);
      expect(() => juzArabicName(31), throwsRangeError);
    });
  });

  group('entity equality', () {
    SurahSummary surah({String audio = 'a'}) => SurahSummary(
      number: 1,
      nameArabic: 'ع',
      nameEnglish: 'E',
      nameTranslation: 't',
      revelationPlace: 'Makkah',
      versesCount: 7,
      bismillahPre: false,
      exampleAudioUrl: audio,
    );

    test('SurahSummary equality ignores audio url but not identity fields', () {
      expect(surah(audio: 'a'), surah(audio: 'b'));
      expect(
        surah(),
        isNot(
          const SurahSummary(
            number: 2,
            nameArabic: 'ع',
            nameEnglish: 'E',
            nameTranslation: 't',
            revelationPlace: 'Makkah',
            versesCount: 7,
            bismillahPre: false,
            exampleAudioUrl: 'a',
          ),
        ),
      );
    });

    test('Juz equality is by juzNumber only', () {
      const verse = JuzVerse(
        verseKey: '1:1',
        surahName: 's',
        ayah: 1,
        arabic: 'a',
        transliteration: 't',
        translations: {},
      );
      expect(
        const Juz(juzNumber: 1, totalVerses: 1, verses: [verse]),
        const Juz(juzNumber: 1, totalVerses: 0, verses: []),
      );
    });

    test('MushafWord equality is by verseKey + position', () {
      MushafWord w(int p, String k) => MushafWord(
        position: p,
        textUthmani: 'x',
        textUthmaniTajweed: 'x',
        lineNumber: 1,
        charTypeName: 'word',
        verseKey: k,
      );
      expect(w(1, '1:1'), w(1, '1:1'));
      expect(w(1, '1:1'), isNot(w(2, '1:1')));
      expect(w(1, '1:1'), isNot(w(1, '1:2')));
    });
  });
}
