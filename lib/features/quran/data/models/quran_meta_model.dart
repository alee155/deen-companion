import '../../domain/entities/quran_meta.dart';
import 'reciter_model.dart';

class QuranMetaModel {
  final int totalSurahs;
  final int totalVerses;
  final int totalJuzs;
  final int totalPages;
  final String textType;
  final List<String> translationsAvailable;
  final List<ReciterModel> reciters;

  const QuranMetaModel({
    required this.totalSurahs,
    required this.totalVerses,
    required this.totalJuzs,
    required this.totalPages,
    required this.textType,
    required this.translationsAvailable,
    required this.reciters,
  });

  factory QuranMetaModel.fromJson(Map<String, dynamic> json) {
    return QuranMetaModel(
      totalSurahs: json['total_surahs'] as int,
      totalVerses: json['total_verses'] as int,
      totalJuzs: json['total_juzs'] as int,
      totalPages: json['total_pages'] as int,
      textType: json['text_type'] as String,
      translationsAvailable: List<String>.from(
        json['translations_available'] as List,
      ),
      reciters: (json['reciters'] as List)
          .map((e) => ReciterModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'total_surahs': totalSurahs,
    'total_verses': totalVerses,
    'total_juzs': totalJuzs,
    'total_pages': totalPages,
    'text_type': textType,
    'translations_available': translationsAvailable,
    'reciters': reciters.map((r) => r.toJson()).toList(),
  };

  QuranMeta toEntity() => QuranMeta(
    totalSurahs: totalSurahs,
    totalVerses: totalVerses,
    totalJuzs: totalJuzs,
    totalPages: totalPages,
    textType: textType,
    translationsAvailable: translationsAvailable,
    reciters: reciters.map((r) => r.toEntity()).toList(),
  );
}
