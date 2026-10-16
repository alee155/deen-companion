import 'package:dio/dio.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/api_error_mapper.dart';
import '../models/points_rule_model.dart';

/// The Bearer token is attached by the Dio `AuthInterceptor`.
abstract class PointsRemoteDataSource {
  /// `GET /points/rules` → `{success, data: [{prayer, points}, …]}`.
  Future<PointsRulesModel> getRules();
}

class PointsRemoteDataSourceImpl implements PointsRemoteDataSource {
  final Dio dio;
  const PointsRemoteDataSourceImpl(this.dio);

  @override
  Future<PointsRulesModel> getRules() async {
    try {
      final body =
          (await dio.get(ApiEndpoints.pointsRules)).data
              as Map<String, dynamic>;
      if (body['success'] != true) throw const ServerException();
      return PointsRulesModel.fromList(body['data'] as List<dynamic>);
    } on DioException catch (e) {
      throw mapDioException(e);
    } on TypeError {
      // The body was not the documented shape.
      throw const ServerException();
    }
  }
}
