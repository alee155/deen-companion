import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/dio_client.dart';
import '../../../auth/presentation/providers/session_keep_alive.dart';
import '../../data/datasources/statistics_remote_datasource.dart';
import '../../data/repositories/statistics_repository_impl.dart';
import '../../domain/entities/group_stats.dart';
import '../../domain/entities/personal_stats.dart';
import '../../domain/entities/stats_common.dart';
import '../../domain/repositories/statistics_repository.dart';

final statisticsRemoteDataSourceProvider = Provider<StatisticsRemoteDataSource>(
  (ref) => StatisticsRemoteDataSourceImpl(ref.watch(dioProvider)),
);

final statisticsRepositoryProvider = Provider<StatisticsRepository>(
  (ref) =>
      StatisticsRepositoryImpl(ref.watch(statisticsRemoteDataSourceProvider)),
);

/// How long a screen's numbers are kept after it closes. Short: they change
/// whenever anyone logs a prayer.
const statisticsKeepAlive = Duration(minutes: 2);

/// The clock the "last N days" window is measured from. Overridden in tests.
final statsClockProvider = Provider<DateTime Function()>((_) => DateTime.now);

/// Bumped whenever a prayer is logged or removed. Every statistic watches it,
/// so the ones on screen refetch and the ones nobody is looking at do nothing
/// (invalidating a provider directly would fetch it even if it was never used).
final statisticsRevisionProvider = StateProvider<int>((ref) => 0);

/// How far back the user is looking. One choice for the whole screen.
final statsPeriodProvider = StateProvider.autoDispose<StatsPeriod>(
  (ref) => StatsPeriod.month,
);

/// The `from` date for the chosen period (null = the server's 30 days).
final _statsFromProvider = Provider.autoDispose<String?>((ref) {
  final period = ref.watch(statsPeriodProvider);
  return period.fromDate(ref.read(statsClockProvider)());
});

/// The group's participation: totals plus one row per day.
final groupOverviewProvider = FutureProvider.autoDispose
    .family<GroupOverview, String>((ref, groupId) async {
      keepAliveForSession(ref, statisticsKeepAlive);
      ref.watch(statisticsRevisionProvider);
      final from = ref.watch(_statsFromProvider);
      final result = await ref
          .watch(statisticsRepositoryProvider)
          .groupOverview(groupId, from: from);
      return result.when(success: (d) => d, failure: (f) => throw f);
    });

/// Every member over the period, in the server's order (points, high to low).
final groupMemberStatsProvider = FutureProvider.autoDispose
    .family<List<GroupMemberStat>, String>((ref, groupId) async {
      keepAliveForSession(ref, statisticsKeepAlive);
      ref.watch(statisticsRevisionProvider);
      final from = ref.watch(_statsFromProvider);
      final result = await ref
          .watch(statisticsRepositoryProvider)
          .groupMembers(groupId, from: from);
      return result.when(success: (d) => d, failure: (f) => throw f);
    });

typedef MemberStatsKey = ({String groupId, String userId});

/// One member, from the day they joined.
final memberStatsDetailProvider = FutureProvider.autoDispose
    .family<MemberStatsDetail, MemberStatsKey>((ref, key) async {
      keepAliveForSession(ref, statisticsKeepAlive);
      ref.watch(statisticsRevisionProvider);
      final from = ref.watch(_statsFromProvider);
      final result = await ref
          .watch(statisticsRepositoryProvider)
          .memberDetail(key.groupId, key.userId, from: from);
      return result.when(success: (d) => d, failure: (f) => throw f);
    });

/// Who needs a nudge (admin only; the server refuses anyone else).
final attentionProvider = FutureProvider.autoDispose
    .family<AttentionReport, String>((ref, groupId) async {
      keepAliveForSession(ref, statisticsKeepAlive);
      ref.watch(statisticsRevisionProvider);
      final result = await ref
          .watch(statisticsRepositoryProvider)
          .attention(groupId);
      return result.when(success: (d) => d, failure: (f) => throw f);
    });

/// The signed-in user's own summary for the period.
final mySummaryProvider = FutureProvider.autoDispose<PersonalSummary>((
  ref,
) async {
  keepAliveForSession(ref, statisticsKeepAlive);
  ref.watch(statisticsRevisionProvider);
  final from = ref.watch(_statsFromProvider);
  final result = await ref
      .watch(statisticsRepositoryProvider)
      .mySummary(from: from);
  return result.when(success: (d) => d, failure: (f) => throw f);
});

/// The signed-in user's own day-by-day record for the period.
final myDailyProvider = FutureProvider.autoDispose<List<DailyStat>>((
  ref,
) async {
  keepAliveForSession(ref, statisticsKeepAlive);
  ref.watch(statisticsRevisionProvider);
  final from = ref.watch(_statsFromProvider);
  final result = await ref
      .watch(statisticsRepositoryProvider)
      .myDaily(from: from);
  return result.when(success: (d) => d, failure: (f) => throw f);
});

/// Statistics change whenever a prayer is logged or removed; call this so
/// whatever is on screen asks the server again.
void invalidateStatistics(Ref ref) {
  ref.read(statisticsRevisionProvider.notifier).state++;
}

/// [invalidateStatistics] for widgets, which hold a `WidgetRef` rather than a
/// `Ref`: `ref.read(refreshStatisticsProvider)()`.
final refreshStatisticsProvider = Provider<void Function()>(
  (ref) =>
      () => invalidateStatistics(ref),
);
