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

  /// Parsed defensively on purpose. The upstream hadith dataset is not
  /// uniformly populated — a handful of entries carry an empty (or absent)
  /// English translation, and hadith numbers occasionally arrive as a decimal
  /// (e.g. 402.2 for a sub-narration). With hard casts, one such record threw
  /// and took down the *entire* 50-hadith page with it; now the bad field
  /// degrades to a sensible default and the rest of the page still reads.
  factory HadithModel.fromJson(Map<String, dynamic> json) {
    return HadithModel(
      id: _asString(json['id']),
      collection: _asString(json['collection']),
      collectionName: _asString(json['collection_name']),
      hadithNumber: _asInt(json['hadithnumber']),
      arabic: _asString(json['arabic']),
      english: _asString(json['english']),
      grade: _asString(json['grade']),
    );
  }

  static String _asString(Object? value) =>
      value is String ? value : (value == null ? '' : value.toString());

  static int _asInt(Object? value) => switch (value) {
    final int v => v,
    final num v => v.round(),
    final String v => int.tryParse(v) ?? num.tryParse(v)?.round() ?? 0,
    _ => 0,
  };

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
