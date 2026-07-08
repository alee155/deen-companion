import 'package:dio/dio.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/ummah_api_response.dart';
import '../models/asma_daily_model.dart';
import '../models/asma_name_model.dart';

abstract class AsmaUlHusnaRemoteDataSource {
  Future<List<AsmaNameModel>> getAllNames();
  Future<AsmaDailyModel> getDailyNames(int day);
  Future<List<AsmaNameModel>> search(String query);
}

class AsmaUlHusnaRemoteDataSourceImpl implements AsmaUlHusnaRemoteDataSource {
  final Dio dio;
  const AsmaUlHusnaRemoteDataSourceImpl(this.dio);

  @override
  Future<List<AsmaNameModel>> getAllNames() async {
    try {
      final response = await dio.get(ApiEndpoints.asmaUlHusna);
      final envelope = UmmahApiResponse.fromJson(
        response.data as Map<String, dynamic>,
        (data) => data,
      );
      final list = envelope.data['names'] as List;
      return list
          .map((e) => AsmaNameModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ServerException(e.message);
    }
  }

  @override
  Future<AsmaDailyModel> getDailyNames(int day) async {
    try {
      final response = await dio.get(ApiEndpoints.asmaUlHusnaDaily(day));
      final envelope = UmmahApiResponse.fromJson(
        response.data as Map<String, dynamic>,
        AsmaDailyModel.fromJson,
      );
      return envelope.data;
    } on DioException catch (e) {
      throw ServerException(e.message);
    }
  }

  @override
  Future<List<AsmaNameModel>> search(String query) async {
    try {
      final response = await dio.get(ApiEndpoints.asmaUlHusnaSearch(query));
      final envelope = UmmahApiResponse.fromJson(
        response.data as Map<String, dynamic>,
        (data) => data,
      );
      final list = envelope.data['results'] as List;
      return list
          .map((e) => AsmaNameModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ServerException(e.message);
    }
  }
}
