import 'package:equatable/equatable.dart';

import '../../groups/domain/entities/group.dart';
import '../../streaks/domain/entities/group_streaks.dart';

/// The group-wide numbers shown in the header.
class GroupNumbers extends Equatable {
  final int memberCount;
  final int goalMetCount;
  final int topCurrentStreak;
  final int bestStreak;

  /// The daily minimum. Only the summary carries it; live events do not.
  final int? minPrayers;

  const GroupNumbers({
    required this.memberCount,
    required this.goalMetCount,
    required this.topCurrentStreak,
    required this.bestStreak,
    this.minPrayers,
  });

  factory GroupNumbers.fromJson(Map<String, dynamic> j) => GroupNumbers(
    memberCount: (j['memberCount'] as num).toInt(),
    goalMetCount: (j['goalMetCount'] as num).toInt(),
    topCurrentStreak: (j['topCurrentStreak'] as num).toInt(),
    bestStreak: (j['bestStreak'] as num).toInt(),
    minPrayers: (j['minPrayers'] as num?)?.toInt(),
  );

  /// These numbers with the ones an event carries; the daily minimum is kept.
  GroupNumbers withSnapshot(GroupNumbers snapshot) => GroupNumbers(
    memberCount: snapshot.memberCount,
    goalMetCount: snapshot.goalMetCount,
    topCurrentStreak: snapshot.topCurrentStreak,
    bestStreak: snapshot.bestStreak,
    minPrayers: minPrayers,
  );

  @override
  List<Object?> get props => [
    memberCount,
    goalMetCount,
    topCurrentStreak,
    bestStreak,
    minPrayers,
  ];
}

/// What an event says about the acting member after the change.
class MemberSnapshot extends Equatable {
  final String userId;
  final int todayCount;
  final int points;
  final int currentStreak;
  final int bestStreak;

  const MemberSnapshot({
    required this.userId,
    required this.todayCount,
    required this.points,
    required this.currentStreak,
    required this.bestStreak,
  });

  factory MemberSnapshot.fromJson(Map<String, dynamic> j) => MemberSnapshot(
    userId: j['userId'] as String,
    todayCount: (j['todayCount'] as num).toInt(),
    points: (j['points'] as num).toInt(),
    currentStreak: (j['currentStreak'] as num).toInt(),
    bestStreak: (j['bestStreak'] as num).toInt(),
  );

  @override
  List<Object?> get props => [
    userId,
    todayCount,
    points,
    currentStreak,
    bestStreak,
  ];
}

/// One member's row in `GET /groups/{id}/summary`.
class LiveMember extends Equatable {
  final String userId;
  final String name;
  final GroupRole role;
  final int todayCount;
  final int todayRequired;
  final bool todayQualified;

  /// Points since this member joined this group (the leaderboard number).
  final int points;
  final int currentStreak;
  final int bestStreak;
  final DateTime? joinedAt;

  const LiveMember({
    required this.userId,
    required this.name,
    required this.role,
    required this.todayCount,
    required this.todayRequired,
    required this.todayQualified,
    required this.points,
    required this.currentStreak,
    required this.bestStreak,
    this.joinedAt,
  });

  factory LiveMember.fromJson(Map<String, dynamic> j) => LiveMember(
    userId: j['userId'] as String,
    name: (j['name'] as String?) ?? '',
    role: GroupRole.parse(j['role'] as String?),
    todayCount: (j['todayCount'] as num).toInt(),
    todayRequired: (j['todayRequired'] as num).toInt(),
    todayQualified: j['todayQualified'] as bool,
    points: (j['points'] as num).toInt(),
    currentStreak: (j['currentStreak'] as num).toInt(),
    bestStreak: (j['bestStreak'] as num).toInt(),
    joinedAt: DateTime.tryParse((j['joinedAt'] as String?) ?? ''),
  );

  /// This member with the numbers from an event. An event does not say what
  /// today needs, so "qualified" is worked out from the row's own minimum; the
  /// next summary corrects it if a rule change makes that differ.
  LiveMember withSnapshot(MemberSnapshot s) => LiveMember(
    userId: userId,
    name: name,
    role: role,
    todayCount: s.todayCount,
    todayRequired: todayRequired,
    todayQualified: s.todayCount >= todayRequired,
    points: s.points,
    currentStreak: s.currentStreak,
    bestStreak: s.bestStreak,
    joinedAt: joinedAt,
  );

  MemberStreak toStreak() => MemberStreak(
    userId: userId,
    name: name,
    role: role,
    currentStreak: currentStreak,
    bestStreak: bestStreak,
    todayCount: todayCount,
    todayRequired: todayRequired,
    todayQualified: todayQualified,
  );

  @override
  List<Object?> get props => [
    userId,
    name,
    role,
    todayCount,
    todayRequired,
    todayQualified,
    points,
    currentStreak,
    bestStreak,
    joinedAt,
  ];
}

/// The numbers and member rows of one group: the answer of
/// `GET /groups/{id}/summary`, and what live events are applied onto.
class GroupSummary extends Equatable {
  final GroupNumbers group;

  /// Leaderboard order: points descending, then who joined first.
  final List<LiveMember> members;

  const GroupSummary({required this.group, required this.members});

  factory GroupSummary.fromJson(Map<String, dynamic> j) => GroupSummary(
    group: GroupNumbers.fromJson(j['group'] as Map<String, dynamic>),
    members: sortLeaderboard([
      for (final m in j['members'] as List)
        LiveMember.fromJson(m as Map<String, dynamic>),
    ]),
  );

  LiveMember? member(String userId) {
    for (final m in members) {
      if (m.userId == userId) return m;
    }
    return null;
  }

  /// This summary after an event: the group's numbers replaced, and the
  /// acting member's row updated (then re-sorted).
  GroupSummary applying({
    required GroupNumbers group,
    required MemberSnapshot member,
  }) => GroupSummary(
    group: this.group.withSnapshot(group),
    members: sortLeaderboard([
      for (final m in members)
        if (m.userId == member.userId) m.withSnapshot(member) else m,
    ]),
  );

  /// The same rows as a streak board, in leaderboard order.
  GroupStreakBoard toBoard() =>
      GroupStreakBoard([for (final m in members) m.toStreak()]);

  @override
  List<Object?> get props => [group, members];
}

/// Points descending, then earliest join first (unknown join times last).
/// Stable for equal keys.
List<LiveMember> sortLeaderboard(List<LiveMember> members) {
  final indexed = members.indexed.toList();
  indexed.sort((a, b) {
    final byPoints = b.$2.points.compareTo(a.$2.points);
    if (byPoints != 0) return byPoints;
    final aj = a.$2.joinedAt, bj = b.$2.joinedAt;
    if (aj != null && bj != null) {
      final byJoin = aj.compareTo(bj);
      if (byJoin != 0) return byJoin;
    } else if (aj != null) {
      return -1;
    } else if (bj != null) {
      return 1;
    }
    return a.$1.compareTo(b.$1);
  });
  return [for (final e in indexed) e.$2];
}
