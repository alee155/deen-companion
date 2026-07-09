import 'package:dio/dio.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/ummah_api_response.dart';
import '../models/mutashabihat_entry_model.dart';
import '../models/mutashabihat_info_model.dart';
import '../models/mutashabihat_surah_page_model.dart';

abstract class MutashabihatRemoteDataSource {
  Future<MutashabihatInfoModel> getInfo();
  Future<MutashabihatEntryModel> getRandom();
  Future<MutashabihatEntryModel> getByAyah(int surah, int ayah);
  Future<MutashabihatSurahPageModel> getSurahPage(int surah, int page);
}

class MutashabihatRemoteDataSourceImpl implements MutashabihatRemoteDataSource {
  final Dio dio;
  const MutashabihatRemoteDataSourceImpl(this.dio);

  // Accepts 404 as a normal (non-throwing) response for endpoints where
  // the API documents 404 as an expected, legitimate outcome — a verse
  // with no known similar verses, or a surah with no mutashabihat entries
  // at all. This keeps those cases out of Dio's error/logging pipeline
  // entirely, since they aren't actually errors.
  static Options get _allow404 =>
      Options(validateStatus: (status) => status != null && status < 500);

  @override
  Future<MutashabihatInfoModel> getInfo() async {
    try {
      final response = await dio.get(ApiEndpoints.mutashabihat);
      final envelope = UmmahApiResponse.fromJson(
        response.data as Map<String, dynamic>,
        MutashabihatInfoModel.fromJson,
      );
      return envelope.data;
    } on DioException catch (e) {
      throw ServerException(e.message);
    }
  }

  @override
  Future<MutashabihatEntryModel> getRandom() async {
    try {
      final response = await dio.get(ApiEndpoints.mutashabihatRandom);
      final envelope = UmmahApiResponse.fromJson(
        response.data as Map<String, dynamic>,
        MutashabihatEntryModel.fromJson,
      );
      return envelope.data;
    } on DioException catch (e) {
      throw ServerException(e.message);
    }
  }

  @override
  Future<MutashabihatEntryModel> getByAyah(int surah, int ayah) async {
    try {
      final response = await dio.get(
        ApiEndpoints.mutashabihatByAyah(surah, ayah),
        options: _allow404,
      );

      if (response.statusCode == 404) throw const NotFoundException();

      final envelope = UmmahApiResponse.fromJson(
        response.data as Map<String, dynamic>,
        MutashabihatEntryModel.fromJson,
      );
      return envelope.data;
    } on DioException catch (e) {
      throw ServerException(e.message);
    }
  }

  @override
  Future<MutashabihatSurahPageModel> getSurahPage(int surah, int page) async {
    try {
      final response = await dio.get(
        ApiEndpoints.mutashabihatBySurah(surah, page: page),
        options: _allow404,
      );

      if (response.statusCode == 404) {
        return MutashabihatSurahPageModel(
          surah: surah,
          surahNameArabic: '',
          surahNameEnglish: '',
          total: 0,
          page: 1,
          limit: 20,
          totalPages: 0,
          entries: const [],
        );
      }

      final envelope = UmmahApiResponse.fromJson(
        response.data as Map<String, dynamic>,
        MutashabihatSurahPageModel.fromJson,
      );
      return envelope.data;
    } on DioException catch (e) {
      throw ServerException(e.message);
    }
  }
}
