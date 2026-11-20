import 'package:equatable/equatable.dart';

class SearchResult extends Equatable {
  final String verseKey;
  final int surahNumber;
  final String surahName;
  final int ayah;
  final String arabic;
  final String transliteration;
  final String translation;

  /// Which translation [translation] is (`sahih_international`, `urdu`, ...).
  final String translationSource;

  const SearchResult({
    required this.verseKey,
    required this.surahNumber,
    required this.surahName,
    required this.ayah,
    required this.arabic,
    required this.transliteration,
    required this.translation,
    this.translationSource = 'sahih_international',
  });

  @override
  List<Object?> get props => [verseKey];
}
