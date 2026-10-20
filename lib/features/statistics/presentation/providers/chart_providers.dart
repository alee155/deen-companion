import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/bars_model.dart';
import '../../domain/entities/group_stats.dart';
import 'statistics_providers.dart';

/// Whose days the chart is showing. The group to begin with; tapping "You" or
/// a member changes it.
final statsSubjectProvider = StateProvider.autoDispose<StatsSubject>(
  (ref) => StatsSubject.group,
);

/// The chart's bars for the chosen subject and period. Each subject is fetched
/// when chosen, so the screen opens on one request, not on all of them.
final statsBarsProvider = Provider.autoDispose
    .family<AsyncValue<BarsModel>, String>((ref, groupId) {
      final subject = ref.watch(statsSubjectProvider);
      switch (subject) {
        case GroupSubject():
          return ref
              .watch(groupOverviewProvider(groupId))
              .whenData(BarsModel.group);
        case MeSubject():
          final summary = ref.watch(mySummaryProvider).valueOrNull;
          return ref
              .watch(myDailyProvider)
              .whenData(
                (daily) => BarsModel.person(
                  title: 'You',
                  daily: daily,
                  average: summary?.completion.percent,
                ),
              );
        case MemberSubject(:final userId):
          return ref
              .watch(
                memberStatsDetailProvider((groupId: groupId, userId: userId)),
              )
              .whenData(
                (d) => BarsModel.person(
                  title: d.member.displayName,
                  daily: d.daily,
                  average: d.completion.percent,
                ),
              );
      }
    });

/// The members' table, and — for the admin only — who needs a nudge, merged
/// into one row per member for the list under the chart.
class MemberRowData {
  final GroupMemberStat stat;

  /// Why the admin should look at this member, or null.
  final AttentionMember? attention;
  const MemberRowData(this.stat, this.attention);
}

/// The rows for the members list. [isAdmin] decides whether the attention
/// report is asked for at all (the server refuses anyone else), and a failure
/// of that report only means no flags are shown.
final memberRowsProvider = Provider.autoDispose
    .family<AsyncValue<List<MemberRowData>>, ({String groupId, bool isAdmin})>((
      ref,
      key,
    ) {
      final flagged = key.isAdmin
          ? {
              for (final m
                  in ref
                          .watch(attentionProvider(key.groupId))
                          .valueOrNull
                          ?.members ??
                      const <AttentionMember>[])
                m.userId: m,
            }
          : const <String, AttentionMember>{};
      return ref
          .watch(groupMemberStatsProvider(key.groupId))
          .whenData(
            (rows) => [
              for (final r in rows) MemberRowData(r, flagged[r.userId]),
            ],
          );
    });
