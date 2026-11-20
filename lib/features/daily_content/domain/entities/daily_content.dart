import '../../../../shared/domain/translation_language.dart';
import '../../../hadith/domain/entities/hadith.dart';

/// The Ayat of the Day: one verse with the identifying info a reader needs.
class DailyAyah {
  final int surahNumber;
  final String surahNameEnglish;
  final String surahNameArabic;
  final int ayahNumber;
  final String arabic;
  final String translation;

  /// The Urdu translation. `null` means "not fetched yet" (content cached by
  /// an older build, before Urdu was kept); an empty string means the source
  /// has none for this verse.
  final String? translationUrdu;

  const DailyAyah({
    required this.surahNumber,
    required this.surahNameEnglish,
    required this.surahNameArabic,
    required this.ayahNumber,
    required this.arabic,
    required this.translation,
    this.translationUrdu,
  });

  /// Whether the Urdu text is known (fetched), so a cached copy that lacks it
  /// can be refreshed.
  bool get urduKnown => translationUrdu != null;

  bool hasUrdu() => (translationUrdu ?? '').trim().isNotEmpty;

  /// The translation in [language]. In Urdu this is the Urdu text, or an empty
  /// string when this verse has none: never the English, which the reader
  /// didn't ask for (callers say the Urdu is unavailable).
  String translationIn(TranslationLanguage language) =>
      language == TranslationLanguage.urdu
      ? (translationUrdu ?? '').trim()
      : translation;

  /// True when [translationIn] is actually Urdu text.
  bool showsUrduFor(TranslationLanguage language) =>
      language == TranslationLanguage.urdu && hasUrdu();

  /// Urdu was asked for but this verse has no Urdu.
  bool urduMissingFor(TranslationLanguage language) =>
      language == TranslationLanguage.urdu && !hasUrdu();

  String get verseKey => '$surahNumber:$ayahNumber';

  String get reference => 'Surah $surahNameEnglish · $verseKey';

  String toShareText({
    TranslationLanguage language = TranslationLanguage.english,
  }) {
    final text = translationIn(language);
    return [arabic, if (text.isNotEmpty) text, '— $reference'].join('\n\n');
  }

  Map<String, dynamic> toJson() => {
    'surah': surahNumber,
    'surah_en': surahNameEnglish,
    'surah_ar': surahNameArabic,
    'ayah': ayahNumber,
    'arabic': arabic,
    'translation': translation,
    'translation_urdu': ?translationUrdu,
  };

  factory DailyAyah.fromJson(Map<String, dynamic> json) => DailyAyah(
    surahNumber: json['surah'] as int,
    surahNameEnglish: json['surah_en'] as String,
    surahNameArabic: json['surah_ar'] as String,
    ayahNumber: json['ayah'] as int,
    arabic: json['arabic'] as String,
    translation: json['translation'] as String,
    translationUrdu: json['translation_urdu'] as String?,
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
