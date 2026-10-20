import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../../core/utils/flow_log.dart';
import '../../../../core/utils/logger.dart';
import '../../domain/entities/group_stats.dart';
import '../../domain/entities/personal_stats.dart';
import '../../domain/entities/stats_common.dart';
import '../../domain/repositories/statistics_repository.dart';
import '../datasources/statistics_remote_datasource.dart';

const _tag = 'STATISTICS';

class StatisticsRepositoryImpl implements StatisticsRepository {
  final StatisticsRemoteDataSource remote;
  const StatisticsRepositoryImpl(this.remote);

  @override
  Future<Result<PersonalSummary>> mySummary({String? from}) => _guard(
    'mySummary',
    () => remote.mySummary(from: from),
    (s) =>
        'MY SUMMARY: ${s.totals.prayersLogged} prayers, '
        '${s.completion.percent ?? '-'}% complete',
  );

  @override
  Future<Result<List<DailyStat>>> myDaily({String? from}) => _guard(
    'myDaily',
    () => remote.myDaily(from: from),
    (d) => 'MY DAILY: ${d.length} days',
  );

  @override
  Future<Result<List<TrendPoint>>> myTrend(
    TrendGranularity granularity, {
    int? periods,
  }) => _guard(
    'myTrend',
    () => remote.myTrend(granularity, periods: periods),
    (t) => 'MY TREND: ${t.length} ${granularity.apiValue}s',
  );

  @override
  Future<Result<GroupOverview>> groupOverview(String groupId, {String? from}) =>
      _guard(
        'groupOverview',
        () => remote.groupOverview(groupId, from: from),
        (o) =>
            'GROUP OVERVIEW: ${o.memberCount} members, ${o.daily.length} days',
      );

  @override
  Future<Result<List<GroupMemberStat>>> groupMembers(
    String groupId, {
    String? from,
  }) => _guard(
    'groupMembers',
    () => remote.groupMembers(groupId, from: from),
    (m) => 'GROUP MEMBERS: ${m.length} rows',
  );

  @override
  Future<Result<MemberStatsDetail>> memberDetail(
    String groupId,
    String userId, {
    String? from,
  }) => _guard(
    'memberDetail',
    () => remote.memberDetail(groupId, userId, from: from),
    (d) => 'MEMBER DETAIL: ${d.daily.length} days',
  );

  @override
  Future<Result<AttentionReport>> attention(
    String groupId, {
    int? inactiveDays,
  }) {
    // Never send what the server will refuse.
    if (inactiveDays != null && (inactiveDays < 1 || inactiveDays > 30)) {
      return Future.value(
        const Error(ServerFailure('Pick between 1 and 30 days.')),
      );
    }
    return _guard(
      'attention',
      () => remote.attention(groupId, inactiveDays: inactiveDays),
      (a) => 'ATTENTION: ${a.members.length} flagged',
    );
  }

  Future<Result<T>> _guard<T>(
    String op,
    Future<T> Function() body,
    String Function(T) describe,
  ) async {
    try {
      final data = await body();
      FlowLog.log(_tag, describe(data));
      return Success(data);
    } on NetworkException {
      FlowLog.error(_tag, '$op: NO CONNECTION');
      return const Error(NetworkFailure());
    } on NotFoundException {
      return const Error(NotFoundFailure());
    } on ServerException catch (e) {
      FlowLog.error(_tag, '$op: SERVER ERROR', '${e.statusCode} ${e.message}');
      final m = e.message;
      return Error(m == null ? const ServerFailure() : ServerFailure(m));
    } catch (e, st) {
      AppLogger.e('StatisticsRepository: $op failed', e, st);
      return const Error(UnexpectedFailure());
    }
  }
}
