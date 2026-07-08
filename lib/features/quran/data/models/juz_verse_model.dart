import '../../domain/entities/juz.dart';

class JuzVerseModel {
  final String verseKey;
  final String surahName;
  final int ayah;
  final String arabic;
  final String transliteration;
  final Map<String, String> translations;

  const JuzVerseModel({
    required this.verseKey,
    required this.surahName,
    required this.ayah,
    required this.arabic,
    required this.transliteration,
    required this.translations,
  });

  factory JuzVerseModel.fromJson(Map<String, dynamic> json) {
    return JuzVerseModel(
      verseKey: json['verse_key'] as String,
      surahName: json['surah_name'] as String,
      ayah: json['ayah'] as int,
      arabic: json['arabic'] as String,
      transliteration: json['transliteration'] as String,
      translations: Map<String, String>.from(json['translations'] as Map),
    );
  }

  Map<String, dynamic> toJson() => {
    'verse_key': verseKey,
    'surah_name': surahName,
    'ayah': ayah,
    'arabic': arabic,
    'transliteration': transliteration,
    'translations': translations,
  };

  JuzVerse toEntity() => JuzVerse(
    verseKey: verseKey,
    surahName: surahName,
    ayah: ayah,
    arabic: arabic,
    transliteration: transliteration,
    translations: translations,
  );
}
