import 'package:equatable/equatable.dart';

class SurahSummary extends Equatable {
  final int number;
  final String nameArabic;
  final String nameEnglish;
  final String nameTranslation;
  final String revelationPlace;
  final int versesCount;
  final bool bismillahPre;
  final String exampleAudioUrl;

  const SurahSummary({
    required this.number,
    required this.nameArabic,
    required this.nameEnglish,
    required this.nameTranslation,
    required this.revelationPlace,
    required this.versesCount,
    required this.bismillahPre,
    required this.exampleAudioUrl,
  });

  @override
  List<Object?> get props => [number, nameArabic, nameEnglish, versesCount];
}
