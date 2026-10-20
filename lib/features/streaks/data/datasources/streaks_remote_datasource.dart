import 'package:dio/dio.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/api_error_mapper.dart';
import '../../domain/entities/group_streaks.dart';
import '../../domain/entities/my_streaks.dart';
import '../../domain/entities/streak_rule.dart';
import '../models/streak_models.dart';

/// The Bearer token is attached by the Dio `AuthInterceptor`.
abstract class StreaksRemoteDataSource {
  Future<StreakRule> getRule(String groupId);
  Future<StreakRule> setRule(String groupId, int minPrayers);
  Future<GroupStreakBoard> getBoard(String groupId);
  Future<MyStreaks> getMine();
}

class StreaksRemoteDataSourceImpl implements StreaksRemoteDataSource {
  final Dio dio;
  const StreaksRemoteDataSourceImpl(this.dio);

  @override
  Future<StreakRule> getRule(String groupId) => _data(
    () => dio.get(ApiEndpoints.groupStreakRule(groupId)),
    (data) => streakRuleFromJson(data as Map<String, dynamic>),
  );

  @override
  Future<StreakRule> setRule(String groupId, int minPrayers) => _data(
    () => dio.patch(
      ApiEndpoints.groupStreakRule(groupId),
      data: {'minPrayers': minPrayers},
    ),
    (data) => streakRuleFromJson(data as Map<String, dynamic>),
  );

  @override
  Future<GroupStreakBoard> getBoard(String groupId) => _data(
    () => dio.get(ApiEndpoints.groupStreaks(groupId)),
    (data) => groupStreakBoardFromJson(data as List<dynamic>),
  );

  @override
  Future<MyStreaks> getMine() => _data(
    () => dio.get(ApiEndpoints.myStreaks),
    (data) => myStreaksFromJson(data as Map<String, dynamic>),
  );

  Future<T> _data<T>(
    Future<Response<dynamic>> Function() call,
    T Function(Object? data) parse,
  ) async {
    try {
      final body = (await call()).data as Map<String, dynamic>;
      if (body['success'] != true) throw const ServerException();
      return parse(body['data']);
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
