import 'search_result_model.dart';

class SearchResponseModel {
  final String query;
  final List<String> searchedIn;
  final int resultsCount;
  final int limit;
  final List<SearchResultModel> results;

  const SearchResponseModel({
    required this.query,
    required this.searchedIn,
    required this.resultsCount,
    required this.limit,
    required this.results,
  });

  factory SearchResponseModel.fromJson(Map<String, dynamic> json) {
    return SearchResponseModel(
      query: json['query'] as String,
      searchedIn: List<String>.from(json['searched_in'] as List),
      resultsCount: json['results_count'] as int,
      limit: json['limit'] as int,
      results: (json['results'] as List)
          .map((e) => SearchResultModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'query': query,
    'searched_in': searchedIn,
    'results_count': resultsCount,
    'limit': limit,
    'results': results.map((r) => r.toJson()).toList(),
  };
}
