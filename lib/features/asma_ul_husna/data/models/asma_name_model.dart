import '../../domain/entities/asma_name.dart';

class AsmaNameModel {
  final int number;
  final String arabic;
  final String transliteration;
  final String english;
  final String meaning;

  const AsmaNameModel({
    required this.number,
    required this.arabic,
    required this.transliteration,
    required this.english,
    required this.meaning,
  });

  factory AsmaNameModel.fromJson(Map<String, dynamic> json) {
    return AsmaNameModel(
      number: json['number'] as int,
      arabic: json['arabic'] as String,
      transliteration: json['transliteration'] as String,
      english: json['english'] as String,
      meaning: json['meaning'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
    'number': number,
    'arabic': arabic,
    'transliteration': transliteration,
    'english': english,
    'meaning': meaning,
  };

  AsmaName toEntity() => AsmaName(
    number: number,
    arabic: arabic,
    transliteration: transliteration,
    english: english,
    meaning: meaning,
  );
}
