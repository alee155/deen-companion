import 'package:dio/dio.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/ummah_api_response.dart';
import '../models/dua_search_response_model.dart';
import '../models/duas_bundle_model.dart';

abstract class DuaRemoteDataSource {
  Future<DuasBundleModel> getBundle();
  Future<DuaSearchResponseModel> search(String query);
}

class DuaRemoteDataSourceImpl implements DuaRemoteDataSource {
  final Dio dio;
  const DuaRemoteDataSourceImpl(this.dio);

  @override
  Future<DuasBundleModel> getBundle() async {
    try {
      final response = await dio.get(ApiEndpoints.duas);
      final envelope = UmmahApiResponse.fromJson(
        response.data as Map<String, dynamic>,
        DuasBundleModel.fromJson,
      );
      return envelope.data;
    } on DioException catch (e) {
      throw ServerException(e.message);
    }
  }

  @override
  Future<DuaSearchResponseModel> search(String query) async {
    try {
      final response = await dio.get(ApiEndpoints.duasSearch(query));
      final envelope = UmmahApiResponse.fromJson(
        response.data as Map<String, dynamic>,
        DuaSearchResponseModel.fromJson,
      );
      return envelope.data;
    } on DioException catch (e) {
      throw ServerException(e.message);
    }
  }
}
