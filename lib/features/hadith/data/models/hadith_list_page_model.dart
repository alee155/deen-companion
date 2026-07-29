import 'hadith_model.dart';

class HadithListPageModel {
  final String collection;
  final String collectionName;
  final int page;
  final int limit;
  final int total;
  final int totalPages;
  final List<HadithModel> hadiths;

  const HadithListPageModel({
    required this.collection,
    required this.collectionName,
    required this.page,
    required this.limit,
    required this.total,
    required this.totalPages,
    required this.hadiths,
  });

  factory HadithListPageModel.fromJson(Map<String, dynamic> json) {
    return HadithListPageModel(
      collection: json['collection'] as String,
      collectionName: json['collection_name'] as String,
      page: json['page'] as int,
      limit: json['limit'] as int,
      total: json['total'] as int,
      totalPages: json['total_pages'] as int,
      hadiths: (json['hadiths'] as List)
          .map((e) => HadithModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'collection': collection,
    'collection_name': collectionName,
    'page': page,
    'limit': limit,
    'total': total,
    'total_pages': totalPages,
    'hadiths': hadiths.map((h) => h.toJson()).toList(),
  };
}
