import 'package:equatable/equatable.dart';
import 'reciter.dart';

class QuranMeta extends Equatable {
  final int totalSurahs;
  final int totalVerses;
  final int totalJuzs;
  final int totalPages;
  final String textType;
  final List<String> translationsAvailable;
  final List<Reciter> reciters;

  const QuranMeta({
    required this.totalSurahs,
    required this.totalVerses,
    required this.totalJuzs,
    required this.totalPages,
    required this.textType,
    required this.translationsAvailable,
    required this.reciters,
  });

  @override
  List<Object?> get props => [
    totalSurahs,
    totalVerses,
    totalJuzs,
    totalPages,
    textType,
    translationsAvailable,
    reciters,
  ];
}
