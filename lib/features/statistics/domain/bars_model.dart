import 'package:equatable/equatable.dart';

import 'entities/group_stats.dart';
import 'entities/stats_common.dart';

/// Who the chart is showing: the group, the viewer, or one member.
sealed class StatsSubject extends Equatable {
  const StatsSubject();

  static const group = GroupSubject();
  static const me = MeSubject();
}

class GroupSubject extends StatsSubject {
  const GroupSubject();
  @override
  List<Object?> get props => const [];
}

class MeSubject extends StatsSubject {
  const MeSubject();
  @override
  List<Object?> get props => const [];
}

class MemberSubject extends StatsSubject {
  final String userId;
  const MemberSubject(this.userId);
  @override
  List<Object?> get props => [userId];
}

/// One day on the chart.
class DayBar extends Equatable {
  /// `YYYY-MM-DD`.
  final String date;

  /// 0–100, or null when there is no data for the day.
  final double? percent;

  /// Today: not over yet, so its bar is drawn lighter.
  final bool partial;

  /// The plain-words reading of the bar ("6 of 8 members reached the goal").
  final String detail;

  const DayBar({
    required this.date,
    required this.percent,
    required this.partial,
    required this.detail,
  });

  DateTime get day => DateTime.parse(date);

  @override
  List<Object?> get props => [date, percent, partial, detail];
}

/// What the chart shows: a bar per day for one subject.
class BarsModel extends Equatable {
  /// "Group", "You" or a member's name.
  final String title;
  final List<DayBar> days;

  /// The period's average for this subject, or null when it has none yet.
  final double? average;

  const BarsModel({
    required this.title,
    required this.days,
    required this.average,
  });

  bool get isEmpty => days.isEmpty;

  /// The bar to start on: today, or the last day when none is flagged.
  int get todayIndex {
    final i = days.lastIndexWhere((d) => d.partial);
    return i >= 0 ? i : (days.isEmpty ? 0 : days.length - 1);
  }

  /// The group: the share of members who reached the daily goal each day.
  factory BarsModel.group(GroupOverview o) => BarsModel(
    title: 'Group',
    average: o.averageParticipationPercent,
    days: [
      for (final d in o.daily)
        DayBar(
          date: d.date,
          percent: d.participationPercent,
          partial: d.isToday,
          detail: d.membersTotal == 0
              ? 'No members yet'
              : '${d.membersQualified} of ${d.membersTotal} members reached '
                    'the goal',
        ),
    ],
  );

  /// A person: the share of the five prayers they prayed each day.
  factory BarsModel.person({
    required String title,
    required List<DailyStat> daily,
    double? average,
  }) => BarsModel(
    title: title,
    average: average,
    days: [
      for (final d in daily)
        DayBar(
          date: d.date,
          percent: d.prayersLogged / 5 * 100,
          partial: d.isToday,
          detail: '${d.prayersLogged} of 5 prayers',
        ),
    ],
  );

  @override
  List<Object?> get props => [title, days, average];
}
