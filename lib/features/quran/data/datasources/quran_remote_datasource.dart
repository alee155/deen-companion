import 'package:dio/dio.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/ummah_api_response.dart';
import '../models/quran_meta_model.dart';
import '../models/surah_summary_model.dart';
import '../models/search_response_model.dart';
import '../models/juz_model.dart';
import '../models/mushaf_page_model.dart';

abstract class QuranRemoteDataSource {
  Future<QuranMetaModel> getQuranMeta();
  Future<List<SurahSummaryModel>> getSurahList();
  Future<SearchResponseModel> searchQuran(
    String query, {
    String translation,
    int limit,
  });
  Future<JuzModel> getJuz(int number);
  Future<MushafPageModel> getMushafPage(int number);
}

class QuranRemoteDataSourceImpl implements QuranRemoteDataSource {
  final Dio dio;
  const QuranRemoteDataSourceImpl(this.dio);

  @override
  Future<QuranMetaModel> getQuranMeta() async {
    try {
      final response = await dio.get(ApiEndpoints.quranMeta);
      final envelope = UmmahApiResponse.fromJson(
        response.data as Map<String, dynamic>,
        QuranMetaModel.fromJson,
      );
      return envelope.data;
    } on DioException catch (e) {
      throw ServerException(e.message);
    }
  }

  @override
  Future<List<SurahSummaryModel>> getSurahList() async {
    try {
      final response = await dio.get(ApiEndpoints.quranSurahs);
      final envelope = UmmahApiResponse.fromJson(
        response.data as Map<String, dynamic>,
        (data) => data, // keep raw here — list needs custom unwrapping below
      );
      final surahsJson = envelope.data['surahs'] as List<dynamic>;
      return surahsJson
          .map(
            (json) => SurahSummaryModel.fromJson(json as Map<String, dynamic>),
          )
          .toList();
    } on DioException catch (e) {
      throw ServerException(e.message);
    }
  }

  @override
  Future<SearchResponseModel> searchQuran(
    String query, {
    String translation = 'sahih_international',
    int limit = 25,
  }) async {
    try {
      final response = await dio.get(
        ApiEndpoints.quranSearch(query, translation: translation, limit: limit),
      );
      final envelope = UmmahApiResponse.fromJson(
        response.data as Map<String, dynamic>,
        SearchResponseModel.fromJson,
      );
      return envelope.data;
    } on DioException catch (e) {
      throw ServerException(e.message);
    }
  }

  @override
  Future<JuzModel> getJuz(int number) async {
    try {
      final response = await dio.get(ApiEndpoints.quranJuz(number));
      final envelope = UmmahApiResponse.fromJson(
        response.data as Map<String, dynamic>,
        JuzModel.fromJson,
      );
      return envelope.data;
    } on DioException catch (e) {
      throw ServerException(e.message);
    }
  }

  @override
  Future<MushafPageModel> getMushafPage(int number) async {
    try {
      final response = await dio.get(ApiEndpoints.quranMushafPage(number));
      final envelope = UmmahApiResponse.fromJson(
        response.data as Map<String, dynamic>,
        MushafPageModel.fromJson,
      );
      return envelope.data;
    } on DioException catch (e) {
      throw ServerException(e.message);
    }
  }
}
