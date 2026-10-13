import 'group_streak.dart';

/// One snap a member sent.
class SnapItem {
  final String id;
  final DateTime sentAt;
  final String? caption;
  final bool viewed;

  const SnapItem({
    required this.id,
    required this.sentAt,
    this.caption,
    this.viewed = false,
  });
}

/// Snap numbers for one member in one group.
///
/// Produced by [SnapStatsRepository]. The backend for this isn't ready, so
/// today it comes from a mock; the UI only depends on this shape.
class MemberSnapStats {
  final String userId;
  final int totalSnaps;
  final int score;
  final int streakDays;
  final bool snappedToday;

  /// Snaps per day for the last N days, oldest first (ends today).
  final List<int> dailyActivity;

  /// Newest first.
  final List<SnapItem> recentSnaps;

  const MemberSnapStats({
    required this.userId,
    required this.totalSnaps,
    required this.score,
    required this.streakDays,
    required this.snappedToday,
    required this.dailyActivity,
    required this.recentSnaps,
  });

  /// The snap shown when the member's snap icon is tapped.
  SnapItem? get latestSnap => recentSnaps.isEmpty ? null : recentSnaps.first;
}

/// Group-level snap numbers for the overview card.
class GroupSnapOverview {
  final int currentStreak;
  final int longestStreak;
  final List<StreakDay> week;
  final int snappedTodayCount;
  final int memberCount;

  /// Stats keyed by member user id.
  final Map<String, MemberSnapStats> members;

  const GroupSnapOverview({
    required this.currentStreak,
    required this.longestStreak,
    required this.week,
    required this.snappedTodayCount,
    required this.memberCount,
    required this.members,
  });

  double get todayProgress =>
      memberCount == 0 ? 0 : snappedTodayCount / memberCount;
}
