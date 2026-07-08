import 'package:equatable/equatable.dart';

class JuzVerse extends Equatable {
  final String verseKey;
  final String surahName;
  final int ayah;
  final String arabic;
  final String transliteration;
  final Map<String, String> translations;

  const JuzVerse({
    required this.verseKey,
    required this.surahName,
    required this.ayah,
    required this.arabic,
    required this.transliteration,
    required this.translations,
  });

  @override
  List<Object?> get props => [verseKey];
}

class Juz extends Equatable {
  final int juzNumber;
  final int totalVerses;
  final List<JuzVerse> verses;

  const Juz({
    required this.juzNumber,
    required this.totalVerses,
    required this.verses,
  });

  @override
  List<Object?> get props => [juzNumber];
}
