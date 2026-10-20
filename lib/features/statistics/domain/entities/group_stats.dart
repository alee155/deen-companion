import 'package:equatable/equatable.dart';

import '../../../groups/domain/entities/group.dart';
import 'stats_common.dart';

class GroupTotals extends Equatable {
  final int prayersLogged;
  final int points;

  /// Member-days on which a member logged all five prayers.
  final int perfectMemberDays;
  final int membersActiveToday;

  const GroupTotals({
    required this.prayersLogged,
    required this.points,
    required this.perfectMemberDays,
    required this.membersActiveToday,
  });

  @override
  List<Object?> get props => [
    prayersLogged,
    points,
    perfectMemberDays,
    membersActiveToday,
  ];
}

/// One day of the group's participation: how many of the members who had
/// joined by then reached the daily goal.
class GroupDay extends Equatable {
  final String date;
  final int prayersLogged;
  final int points;
  final int membersQualified;
  final int membersTotal;

  /// Null when nobody had joined yet.
  final double? participationPercent;
  final bool isToday;

  const GroupDay({
    required this.date,
    required this.prayersLogged,
    required this.points,
    required this.membersQualified,
    required this.membersTotal,
    required this.participationPercent,
    required this.isToday,
  });

  DateTime get day => DateTime.parse(date);

  @override
  List<Object?> get props => [
    date,
    prayersLogged,
    points,
    membersQualified,
    membersTotal,
    participationPercent,
    isToday,
  ];
}

/// `GET /groups/{id}/stats/overview`.
class GroupOverview extends Equatable {
  final int memberCount;
  final GroupTotals totals;

  /// Average over the finished days only; null when there are none.
  final double? averageParticipationPercent;
  final List<GroupDay> daily;

  const GroupOverview({
    required this.memberCount,
    required this.totals,
    required this.averageParticipationPercent,
    required this.daily,
  });

  @override
  List<Object?> get props => [
    memberCount,
    totals,
    averageParticipationPercent,
    daily,
  ];
}

/// One row of `GET /groups/{id}/stats/members`.
class GroupMemberStat extends Equatable {
  final String userId;
  final String name;
  final GroupRole role;
  final int prayersLogged;
  final int points;
  final int activeDays;
  final int perfectDays;
  final double? completionPercent;
  final int currentStreak;

  const GroupMemberStat({
    required this.userId,
    required this.name,
    required this.role,
    required this.prayersLogged,
    required this.points,
    required this.activeDays,
    required this.perfectDays,
    required this.completionPercent,
    required this.currentStreak,
  });

  String get displayName => name.trim().isEmpty ? 'Member' : name.trim();

  @override
  List<Object?> get props => [
    userId,
    name,
    role,
    prayersLogged,
    points,
    activeDays,
    perfectDays,
    completionPercent,
    currentStreak,
  ];
}

class MemberIdentity extends Equatable {
  final String userId;
  final String name;
  final GroupRole role;
  final DateTime? joinedAt;

  const MemberIdentity({
    required this.userId,
    required this.name,
    required this.role,
    required this.joinedAt,
  });

  String get displayName => name.trim().isEmpty ? 'Member' : name.trim();

  @override
  List<Object?> get props => [userId, name, role, joinedAt];
}

/// `GET /groups/{id}/stats/members/{userId}`: one member, from the day they
/// joined.
class MemberStatsDetail extends Equatable {
  final MemberIdentity member;
  final StatsRange range;
  final PeriodTotals totals;
  final Completion completion;
  final List<DailyStat> daily;
  final List<PrayerStat> perPrayer;

  const MemberStatsDetail({
    required this.member,
    required this.range,
    required this.totals,
    required this.completion,
    required this.daily,
    required this.perPrayer,
  });

  @override
  List<Object?> get props => [
    member,
    range,
    totals,
    completion,
    daily,
    perPrayer,
  ];
}

/// Why a member is on the admin's "needs attention" list.
enum AttentionFlag {
  /// Joined at least a day ago and never logged a prayer.
  neverLogged,

  /// No log for the chosen number of days or more.
  inactive,

  /// Completion fell sharply from the week before.
  declining;

  static AttentionFlag? parse(String? raw) => switch (raw) {
    'never_logged' => AttentionFlag.neverLogged,
    'inactive' => AttentionFlag.inactive,
    'declining' => AttentionFlag.declining,
    _ => null,
  };
}

class AttentionMember extends Equatable {
  final String userId;
  final String name;
  final List<AttentionFlag> flags;
  final String? lastLoggedDate;
  final int? daysSinceLastLog;
  final double? completionLast7;
  final double? completionPrev7;

  const AttentionMember({
    required this.userId,
    required this.name,
    required this.flags,
    required this.lastLoggedDate,
    required this.daysSinceLastLog,
    required this.completionLast7,
    required this.completionPrev7,
  });

  String get displayName => name.trim().isEmpty ? 'Member' : name.trim();

  @override
  List<Object?> get props => [
    userId,
    name,
    flags,
    lastLoggedDate,
    daysSinceLastLog,
    completionLast7,
    completionPrev7,
  ];
}

/// `GET /groups/{id}/stats/attention` (admin only): only flagged members.
class AttentionReport extends Equatable {
  final String asOf;
  final int inactiveDaysThreshold;
  final List<AttentionMember> members;

  const AttentionReport({
    required this.asOf,
    required this.inactiveDaysThreshold,
    required this.members,
  });

  bool get isEmpty => members.isEmpty;

  @override
  List<Object?> get props => [asOf, inactiveDaysThreshold, members];
}
