import '../../domain/entities/hadith.dart';

class HadithModel {
  final String id;
  final String collection;
  final String collectionName;
  final int hadithNumber;
  final String arabic;
  final String english;
  final String grade;

  const HadithModel({
    required this.id,
    required this.collection,
    required this.collectionName,
    required this.hadithNumber,
    required this.arabic,
    required this.english,
    required this.grade,
  });

  factory HadithModel.fromJson(Map<String, dynamic> json) {
    return HadithModel(
      id: json['id'] as String,
      collection: json['collection'] as String,
      collectionName: json['collection_name'] as String,
      hadithNumber: json['hadithnumber'] as int,
      arabic: json['arabic'] as String,
      english: json['english'] as String,
      grade: json['grade'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'collection': collection,
    'collection_name': collectionName,
    'hadithnumber': hadithNumber,
    'arabic': arabic,
    'english': english,
    'grade': grade,
  };

  Hadith toEntity() => Hadith(
    id: id,
    collection: collection,
    collectionName: collectionName,
    hadithNumber: hadithNumber,
    arabic: arabic,
    english: english,
    grade: grade,
  );
}
