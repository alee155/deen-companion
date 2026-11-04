import 'package:dio/dio.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/api_error_mapper.dart';
import '../../domain/entities/leaderboard_entry.dart';
import '../models/leaderboard_models.dart';

/// The Bearer token is attached by the Dio `AuthInterceptor`.
abstract class LeaderboardRemoteDataSource {
  Future<List<LeaderboardEntry>> leaderboard(String groupId);
}

class LeaderboardRemoteDataSourceImpl implements LeaderboardRemoteDataSource {
  final Dio dio;
  const LeaderboardRemoteDataSourceImpl(this.dio);

  @override
  Future<List<LeaderboardEntry>> leaderboard(String groupId) async {
    try {
      final response = await dio.get(ApiEndpoints.groupLeaderboard(groupId));
      final body = response.data;
      if (body is Map<String, dynamic> && body['success'] == false) {
        throw const ServerException();
      }
      return leaderboardFromJson(body);
    } on DioException catch (e) {
      throw mapDioException(e);
    } on TypeError {
      // The body was not the documented shape.
      throw const ServerException();
    } on FormatException {
      throw const ServerException();
    }
  }
}
