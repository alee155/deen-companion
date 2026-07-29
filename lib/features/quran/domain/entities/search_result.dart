import 'package:equatable/equatable.dart';

class SearchResult extends Equatable {
  final String verseKey;
  final int surahNumber;
  final String surahName;
  final int ayah;
  final String arabic;
  final String transliteration;
  final String translation;

  const SearchResult({
    required this.verseKey,
    required this.surahNumber,
    required this.surahName,
    required this.ayah,
    required this.arabic,
    required this.transliteration,
    required this.translation,
  });

  @override
  List<Object?> get props => [verseKey];
}
