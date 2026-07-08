import '../../domain/entities/search_result.dart';

class SearchResultModel {
  final String verseKey;
  final int surahNumber;
  final String surahName;
  final int ayah;
  final String arabic;
  final String transliteration;
  final String translation;
  final String matchedIn;
  final String translationSource;

  const SearchResultModel({
    required this.verseKey,
    required this.surahNumber,
    required this.surahName,
    required this.ayah,
    required this.arabic,
    required this.transliteration,
    required this.translation,
    required this.matchedIn,
    required this.translationSource,
  });

  factory SearchResultModel.fromJson(Map<String, dynamic> json) {
    return SearchResultModel(
      verseKey: json['verse_key'] as String,
      surahNumber: json['surah_number'] as int,
      surahName: json['surah_name'] as String,
      ayah: json['ayah'] as int,
      arabic: json['arabic'] as String,
      transliteration: json['transliteration'] as String,
      translation: json['translation'] as String,
      matchedIn: json['matched_in'] as String,
      translationSource: json['translation_source'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
    'verse_key': verseKey,
    'surah_number': surahNumber,
    'surah_name': surahName,
    'ayah': ayah,
    'arabic': arabic,
    'transliteration': transliteration,
    'translation': translation,
    'matched_in': matchedIn,
    'translation_source': translationSource,
  };

  SearchResult toEntity() => SearchResult(
    verseKey: verseKey,
    surahNumber: surahNumber,
    surahName: surahName,
    ayah: ayah,
    arabic: arabic,
    transliteration: transliteration,
    translation: translation,
  );
}
