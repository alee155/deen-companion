import '../../domain/entities/juz.dart';
import 'juz_verse_model.dart';

class JuzModel {
  final int juzNumber;
  final int totalVerses;
  final List<JuzVerseModel> verses;

  const JuzModel({
    required this.juzNumber,
    required this.totalVerses,
    required this.verses,
  });

  factory JuzModel.fromJson(Map<String, dynamic> json) {
    return JuzModel(
      juzNumber: json['juz_number'] as int,
      totalVerses: json['total_verses'] as int,
      verses: (json['verses'] as List)
          .map((e) => JuzVerseModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'juz_number': juzNumber,
    'total_verses': totalVerses,
    'verses': verses.map((v) => v.toJson()).toList(),
  };

  Juz toEntity() => Juz(
    juzNumber: juzNumber,
    totalVerses: totalVerses,
    verses: verses.map((v) => v.toEntity()).toList(),
  );
}
