import '../../domain/entities/dua.dart';

class DuaModel {
  final int id;
  final String category;
  final String title;
  final String arabic;
  final String transliteration;
  final String translation;
  final String source;
  final int repeat;

  const DuaModel({
    required this.id,
    required this.category,
    required this.title,
    required this.arabic,
    required this.transliteration,
    required this.translation,
    required this.source,
    required this.repeat,
  });

  factory DuaModel.fromJson(Map<String, dynamic> json) {
    return DuaModel(
      id: json['id'] as int,
      category: json['category'] as String,
      title: json['title'] as String,
      arabic: json['arabic'] as String,
      transliteration: json['transliteration'] as String,
      translation: json['translation'] as String,
      source: json['source'] as String,
      repeat: json['repeat'] as int,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'category': category,
    'title': title,
    'arabic': arabic,
    'transliteration': transliteration,
    'translation': translation,
    'source': source,
    'repeat': repeat,
  };

  Dua toEntity() => Dua(
    id: id,
    category: category,
    title: title,
    arabic: arabic,
    transliteration: transliteration,
    translation: translation,
    source: source,
    repeat: repeat,
  );
}
