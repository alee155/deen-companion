import 'package:dio/dio.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/api_error_mapper.dart';
import '../../domain/entities/group_stats.dart';
import '../../domain/entities/personal_stats.dart';
import '../../domain/entities/stats_common.dart';
import '../models/stats_models.dart';

/// The Bearer token is attached by the Dio `AuthInterceptor`.
abstract class StatisticsRemoteDataSource {
  Future<PersonalSummary> mySummary({String? from});
  Future<List<DailyStat>> myDaily({String? from});
  Future<List<TrendPoint>> myTrend(
    TrendGranularity granularity, {
    int? periods,
  });
  Future<GroupOverview> groupOverview(String groupId, {String? from});
  Future<List<GroupMemberStat>> groupMembers(String groupId, {String? from});
  Future<MemberStatsDetail> memberDetail(
    String groupId,
    String userId, {
    String? from,
  });
  Future<AttentionReport> attention(String groupId, {int? inactiveDays});
}

class StatisticsRemoteDataSourceImpl implements StatisticsRemoteDataSource {
  final Dio dio;
  const StatisticsRemoteDataSourceImpl(this.dio);

  /// Query parameters, leaving out the ones not given.
  static Map<String, dynamic> _q(Map<String, Object?> params) => {
    for (final e in params.entries)
      if (e.value != null) e.key: e.value,
  };

  @override
  Future<PersonalSummary> mySummary({String? from}) => _data(
    () => dio.get(
      ApiEndpoints.myStatsSummary,
      queryParameters: _q({'from': from}),
    ),
    personalSummaryFromJson,
  );

  @override
  Future<List<DailyStat>> myDaily({String? from}) => _data(
    () =>
        dio.get(ApiEndpoints.myStatsDaily, queryParameters: _q({'from': from})),
    dailyListFromJson,
  );

  @override
  Future<List<TrendPoint>> myTrend(
    TrendGranularity granularity, {
    int? periods,
  }) => _data(
    () => dio.get(
      ApiEndpoints.myStatsTrend,
      queryParameters: _q({
        'granularity': granularity.apiValue,
        'periods': periods,
      }),
    ),
    trendFromJson,
  );

  @override
  Future<GroupOverview> groupOverview(String groupId, {String? from}) => _data(
    () => dio.get(
      ApiEndpoints.groupStatsOverview(groupId),
      queryParameters: _q({'from': from}),
    ),
    groupOverviewFromJson,
  );

  @override
  Future<List<GroupMemberStat>> groupMembers(String groupId, {String? from}) =>
      _data(
        () => dio.get(
          ApiEndpoints.groupStatsMembers(groupId),
          queryParameters: _q({'from': from}),
        ),
        groupMembersFromJson,
      );

  @override
  Future<MemberStatsDetail> memberDetail(
    String groupId,
    String userId, {
    String? from,
  }) => _data(
    () => dio.get(
      ApiEndpoints.groupStatsMember(groupId, userId),
      queryParameters: _q({'from': from}),
    ),
    memberDetailFromJson,
  );

  @override
  Future<AttentionReport> attention(String groupId, {int? inactiveDays}) =>
      _data(
        () => dio.get(
          ApiEndpoints.groupStatsAttention(groupId),
          queryParameters: _q({'inactiveDays': inactiveDays}),
        ),
        attentionFromJson,
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
