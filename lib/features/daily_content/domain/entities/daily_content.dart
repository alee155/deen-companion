import '../../../hadith/domain/entities/hadith.dart';

/// The Ayat of the Day: one verse with the identifying info a reader needs.
class DailyAyah {
  final int surahNumber;
  final String surahNameEnglish;
  final String surahNameArabic;
  final int ayahNumber;
  final String arabic;
  final String translation;

  const DailyAyah({
    required this.surahNumber,
    required this.surahNameEnglish,
    required this.surahNameArabic,
    required this.ayahNumber,
    required this.arabic,
    required this.translation,
  });

  String get verseKey => '$surahNumber:$ayahNumber';

  String get reference => 'Surah $surahNameEnglish · $verseKey';

  String toShareText() => '$arabic\n\n$translation\n\n— $reference';

  Map<String, dynamic> toJson() => {
    'surah': surahNumber,
    'surah_en': surahNameEnglish,
    'surah_ar': surahNameArabic,
    'ayah': ayahNumber,
    'arabic': arabic,
    'translation': translation,
  };

  factory DailyAyah.fromJson(Map<String, dynamic> json) => DailyAyah(
    surahNumber: json['surah'] as int,
    surahNameEnglish: json['surah_en'] as String,
    surahNameArabic: json['surah_ar'] as String,
    ayahNumber: json['ayah'] as int,
    arabic: json['arabic'] as String,
    translation: json['translation'] as String,
  );
}

/// Both pieces of content for one calendar day.
class DailyContent {
  /// 'yyyy-MM-dd' of the day the content belongs to.
  final String dateKey;
  final DailyAyah ayah;
  final Hadith hadith;

  const DailyContent({
    required this.dateKey,
    required this.ayah,
    required this.hadith,
  });
}
