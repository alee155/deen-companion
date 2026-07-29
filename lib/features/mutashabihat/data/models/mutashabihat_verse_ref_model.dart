import '../../domain/entities/mutashabihat_verse_ref.dart';

class MutashabihatVerseRefModel {
  final String verseKey;
  final int surah;
  final int ayah;
  final String surahNameArabic;
  final String surahNameEnglish;
  final String arabic;
  final String translation;

  const MutashabihatVerseRefModel({
    required this.verseKey,
    required this.surah,
    required this.ayah,
    required this.surahNameArabic,
    required this.surahNameEnglish,
    required this.arabic,
    required this.translation,
  });

  // Works for both the base verse (called on the outer JSON, which has
  // an extra "similar_verses" key that's simply ignored here) and each
  // item inside "similar_verses" — same seven fields either way.
  factory MutashabihatVerseRefModel.fromJson(Map<String, dynamic> json) {
    return MutashabihatVerseRefModel(
      verseKey: json['verse_key'] as String,
      surah: json['surah'] as int,
      ayah: json['ayah'] as int,
      surahNameArabic: json['surah_name_arabic'] as String,
      surahNameEnglish: json['surah_name_english'] as String,
      arabic: json['arabic'] as String,
      translation: json['translation'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
    'verse_key': verseKey,
    'surah': surah,
    'ayah': ayah,
    'surah_name_arabic': surahNameArabic,
    'surah_name_english': surahNameEnglish,
    'arabic': arabic,
    'translation': translation,
  };

  MutashabihatVerseRef toEntity() => MutashabihatVerseRef(
    verseKey: verseKey,
    surah: surah,
    ayah: ayah,
    surahNameArabic: surahNameArabic,
    surahNameEnglish: surahNameEnglish,
    arabic: arabic,
    translation: translation,
  );
}
