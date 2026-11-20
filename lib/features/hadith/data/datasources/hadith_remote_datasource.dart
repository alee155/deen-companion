import 'package:dio/dio.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/ummah_api_response.dart';
import '../models/hadith_collection_model.dart';
import '../models/hadith_list_page_model.dart';
import '../models/hadith_model.dart';

abstract class HadithRemoteDataSource {
  Future<List<HadithCollectionModel>> getCollections();
  Future<HadithListPageModel> getHadithPage(String collection, int page);
  Future<HadithModel> getRandomHadith();

  /// One hadith by its number in a book, or null when the book has none.
  Future<HadithModel?> getHadithByNumber(String collection, int number);
  Future<List<HadithModel>> search(
    String query, {
    String? collection,
    int limit = 25,
  });
}

class HadithRemoteDataSourceImpl implements HadithRemoteDataSource {
  final Dio dio;
  const HadithRemoteDataSourceImpl(this.dio);

  @override
  Future<List<HadithCollectionModel>> getCollections() async {
    try {
      final response = await dio.get(ApiEndpoints.hadithCollections);
      final envelope = UmmahApiResponse.fromJson(
        response.data as Map<String, dynamic>,
        (data) => data,
      );
      final list = envelope.data['collections'] as List;
      return list
          .map((e) => HadithCollectionModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ServerException(e.message);
    }
  }

  @override
  Future<HadithListPageModel> getHadithPage(String collection, int page) async {
    try {
      final response = await dio.get(ApiEndpoints.hadithPage(collection, page));
      final envelope = UmmahApiResponse.fromJson(
        response.data as Map<String, dynamic>,
        HadithListPageModel.fromJson,
      );
      return envelope.data;
    } on DioException catch (e) {
      throw ServerException(e.message);
    }
  }

  @override
  Future<HadithModel> getRandomHadith() async {
    try {
      final response = await dio.get(ApiEndpoints.hadithRandom);
      final envelope = UmmahApiResponse.fromJson(
        response.data as Map<String, dynamic>,
        HadithModel.fromJson,
      );
      return envelope.data;
    } on DioException catch (e) {
      throw ServerException(e.message);
    }
  }

  @override
  Future<HadithModel?> getHadithByNumber(String collection, int number) async {
    try {
      final response = await dio.get(
        ApiEndpoints.hadithByNumber(collection, number),
      );
      final data =
          (response.data as Map<String, dynamic>)['data']
              as Map<String, dynamic>;
      return HadithModel.fromJson(data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      throw ServerException(e.message);
    }
  }

  @override
  Future<List<HadithModel>> search(
    String query, {
    String? collection,
    int limit = 25,
  }) async {
    try {
      final response = await dio.get(
        ApiEndpoints.hadithSearch(query, collection: collection, limit: limit),
      );
      final envelope = UmmahApiResponse.fromJson(
        response.data as Map<String, dynamic>,
        (data) => data,
      );
      final list = envelope.data['hadiths'] as List;
      return list
          .map((e) => HadithModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ServerException(e.message);
    }
  }
}
