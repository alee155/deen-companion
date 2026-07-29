import '../../domain/entities/surah_summary.dart';
import 'surah_audio_info_model.dart';

class SurahSummaryModel {
  final int number;
  final String nameArabic;
  final String nameEnglish;
  final String nameTranslation;
  final String revelationPlace;
  final int versesCount;
  final bool bismillahPre;
  final SurahAudioInfoModel audio;

  const SurahSummaryModel({
    required this.number,
    required this.nameArabic,
    required this.nameEnglish,
    required this.nameTranslation,
    required this.revelationPlace,
    required this.versesCount,
    required this.bismillahPre,
    required this.audio,
  });

  factory SurahSummaryModel.fromJson(Map<String, dynamic> json) {
    return SurahSummaryModel(
      number: json['number'] as int,
      nameArabic: json['name_arabic'] as String,
      nameEnglish: json['name_english'] as String,
      nameTranslation: json['name_translation'] as String,
      revelationPlace: json['revelation_place'] as String,
      versesCount: json['verses_count'] as int,
      bismillahPre: json['bismillah_pre'] as bool,
      audio: SurahAudioInfoModel.fromJson(
        json['audio'] as Map<String, dynamic>,
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'number': number,
    'name_arabic': nameArabic,
    'name_english': nameEnglish,
    'name_translation': nameTranslation,
    'revelation_place': revelationPlace,
    'verses_count': versesCount,
    'bismillah_pre': bismillahPre,
    'audio': audio.toJson(),
  };

  SurahSummary toEntity() => SurahSummary(
    number: number,
    nameArabic: nameArabic,
    nameEnglish: nameEnglish,
    nameTranslation: nameTranslation,
    revelationPlace: revelationPlace,
    versesCount: versesCount,
    bismillahPre: bismillahPre,
    exampleAudioUrl: audio.exampleAudio,
  );
}
