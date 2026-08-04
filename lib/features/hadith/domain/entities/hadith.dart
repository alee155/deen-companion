import '../hadith_grade.dart';

class Hadith {
  final String id;
  final String collection;
  final String collectionName;
  final int hadithNumber;
  final String arabic;
  final String english;
  final String grade;

  const Hadith({
    required this.id,
    required this.collection,
    required this.collectionName,
    required this.hadithNumber,
    required this.arabic,
    required this.english,
    required this.grade,
  });

  /// A small number of entries in the source dataset carry no English text at
  /// all. The reader says so explicitly rather than rendering a blank gap the
  /// user reads as a bug.
  bool get hasTranslation => english.trim().isNotEmpty;

  bool get hasArabic => arabic.trim().isNotEmpty;

  HadithGrade get gradeLevel => HadithGrade.parse(grade);

  /// Plain-text form used for Copy and Share, with attribution so a pasted
  /// hadith never loses its reference.
  String toShareText() {
    final parts = <String>[
      if (hasArabic) arabic.trim(),
      if (hasTranslation) english.trim(),
      '— $collectionName, Hadith $hadithNumber'
          '${grade.trim().isEmpty ? '' : ' (${grade.trim()})'}',
    ];
    return parts.join('\n\n');
  }
}
