import '../../domain/entities/hadith_collection.dart';

class HadithCollectionModel {
  final String key;
  final String name;
  final String arabicName;
  final String author;
  final String reliability;
  final int totalHadiths;

  const HadithCollectionModel({
    required this.key,
    required this.name,
    required this.arabicName,
    required this.author,
    required this.reliability,
    required this.totalHadiths,
  });

  factory HadithCollectionModel.fromJson(Map<String, dynamic> json) {
    return HadithCollectionModel(
      key: json['key'] as String,
      name: json['name'] as String,
      arabicName: json['arabic_name'] as String,
      author: json['author'] as String,
      reliability: json['reliability'] as String,
      totalHadiths: json['total_hadiths'] as int,
    );
  }

  Map<String, dynamic> toJson() => {
    'key': key,
    'name': name,
    'arabic_name': arabicName,
    'author': author,
    'reliability': reliability,
    'total_hadiths': totalHadiths,
  };

  HadithCollection toEntity() => HadithCollection(
    key: key,
    name: name,
    arabicName: arabicName,
    author: author,
    reliability: reliability,
    totalHadiths: totalHadiths,
  );
}
