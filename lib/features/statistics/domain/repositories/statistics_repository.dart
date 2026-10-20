import '../../../../core/usecase/usecase.dart';
import '../entities/group_stats.dart';
import '../entities/personal_stats.dart';
import '../entities/stats_common.dart';

/// Everything is computed by the server from the prayer logs on each request,
/// so nothing here is cached. `from` is the first day (`YYYY-MM-DD`); leaving
/// it out gives the server's default of the last 30 days, ending today.
abstract class StatisticsRepository {
  /// `GET /users/me/stats/summary`.
  Future<Result<PersonalSummary>> mySummary({String? from});

  /// `GET /users/me/stats/daily` — one row per day, zero-filled.
  Future<Result<List<DailyStat>>> myDaily({String? from});

  /// `GET /users/me/stats/trend` — oldest to newest, ending in the running
  /// week or month. [periods] is 1–12; omit for the server default.
  Future<Result<List<TrendPoint>>> myTrend(
    TrendGranularity granularity, {
    int? periods,
  });

  /// `GET /groups/{id}/stats/overview` — any member.
  Future<Result<GroupOverview>> groupOverview(String groupId, {String? from});

  /// `GET /groups/{id}/stats/members` — any member, sorted by points.
  Future<Result<List<GroupMemberStat>>> groupMembers(
    String groupId, {
    String? from,
  });

  /// `GET /groups/{id}/stats/members/{userId}` — any member.
  Future<Result<MemberStatsDetail>> memberDetail(
    String groupId,
    String userId, {
    String? from,
  });

  /// `GET /groups/{id}/stats/attention` — admin only. [inactiveDays] is 1–30;
  /// omit for the server default of 3.
  Future<Result<AttentionReport>> attention(
    String groupId, {
    int? inactiveDays,
  });
}
