import 'dua_model.dart';

class DuaSearchResponseModel {
  final String query;
  final int resultsCount;
  final List<DuaModel> results;

  const DuaSearchResponseModel({
    required this.query,
    required this.resultsCount,
    required this.results,
  });

  factory DuaSearchResponseModel.fromJson(Map<String, dynamic> json) {
    return DuaSearchResponseModel(
      query: json['query'] as String,
      resultsCount: json['results_count'] as int,
      results: (json['results'] as List)
          .map((e) => DuaModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
