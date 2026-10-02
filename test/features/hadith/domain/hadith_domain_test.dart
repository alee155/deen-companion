import 'package:deen_companion/features/hadith/domain/entities/hadith.dart';
import 'package:deen_companion/features/hadith/domain/hadith_cover_assets.dart';
import 'package:deen_companion/features/hadith/domain/hadith_grade.dart';
import 'package:flutter_test/flutter_test.dart';

Hadith h({
  String arabic = 'ar',
  String english = 'en',
  String grade = 'Sahih',
}) => Hadith(
  id: 'i',
  collection: 'c',
  collectionName: 'Collection',
  hadithNumber: 12,
  arabic: arabic,
  english: english,
  grade: grade,
);

void main() {
  group('HadithGrade.parse', () {
    test('Arabic gradings are recognised', () {
      expect(HadithGrade.parse('صحيح'), HadithGrade.sahih);
      expect(HadithGrade.parse('حسن'), HadithGrade.hasan);
      expect(HadithGrade.parse('ضعيف'), HadithGrade.daif);
    });

    test('all Da\'if spellings map to daif', () {
      for (final s in [
        "Da'if",
        'Daif',
        'Dhaif',
        'weak chain',
        'DA\'IF (Albani)',
      ]) {
        expect(HadithGrade.parse(s), HadithGrade.daif, reason: s);
      }
    });

    test('sahih wins when multiple grades appear', () {
      expect(HadithGrade.parse('Sahih / Hasan'), HadithGrade.sahih);
      expect(HadithGrade.parse('Hasan, weak in one chain'), HadithGrade.hasan);
    });

    test('null, empty and junk are unknown', () {
      expect(HadithGrade.parse(null), HadithGrade.unknown);
      expect(HadithGrade.parse(''), HadithGrade.unknown);
      expect(HadithGrade.parse('Mawdu'), HadithGrade.unknown);
    });

    test('labels', () {
      expect(HadithGrade.sahih.label, 'Sahih');
      expect(HadithGrade.hasan.label, 'Hasan');
      expect(HadithGrade.daif.label, "Da'if");
      expect(HadithGrade.unknown.label, 'Ungraded');
    });
  });

  group('Hadith entity', () {
    test('hasTranslation / hasArabic treat whitespace as empty', () {
      expect(h(english: '  \n').hasTranslation, isFalse);
      expect(h(arabic: ' ').hasArabic, isFalse);
      expect(h().hasTranslation, isTrue);
    });

    test('gradeLevel delegates to HadithGrade', () {
      expect(h(grade: 'Hasan').gradeLevel, HadithGrade.hasan);
    });

    test('toShareText: full form is arabic, english, then attribution', () {
      expect(h().toShareText(), 'ar\n\nen\n\n— Collection, Hadith 12 (Sahih)');
    });

    test('toShareText trims text and omits blank grade parentheses', () {
      expect(
        h(arabic: ' ar ', english: ' en ', grade: '  ').toShareText(),
        'ar\n\nen\n\n— Collection, Hadith 12',
      );
    });

    test('toShareText with neither text still carries the reference', () {
      expect(
        h(arabic: '', english: '').toShareText(),
        '— Collection, Hadith 12 (Sahih)',
      );
    });
  });

  group('HadithCoverAssets', () {
    test('hasCover agrees with forKey', () {
      for (final key in ['bukhari', 'muslim', 'nawawi', '', 'BUKHARI']) {
        expect(
          HadithCoverAssets.hasCover(key),
          HadithCoverAssets.forKey(key) != null,
          reason: key,
        );
      }
    });

    test('lookup is case-sensitive', () {
      expect(HadithCoverAssets.forKey('Bukhari'), isNull);
      expect(HadithCoverAssets.forKey('bukhari'), contains('bukhari'));
    });
  });
}
