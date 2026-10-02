class StreakDay {
  final DateTime date;
  final bool completed;
  final bool isToday;

  const StreakDay({
    required this.date,
    required this.completed,
    this.isToday = false,
  });
}

class MemberActivity {
  final String id;
  final String name;
  final String? imagePath;
  final int streakDays;
  final bool completedToday;

  const MemberActivity({
    required this.id,
    required this.name,
    required this.streakDays,
    required this.completedToday,
    this.imagePath,
  });

  String get initials {
    final parts = name.split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    return parts.take(2).map((p) => p[0].toUpperCase()).join();
  }
}

class GroupStreakSummary {
  final String groupId;
  final String groupName;
  final int currentStreak;
  final int longestStreak;
  final List<StreakDay> week;
  final int memberCount;
  final int completedTodayCount;
  final List<MemberActivity> members;

  const GroupStreakSummary({
    required this.groupId,
    required this.groupName,
    required this.currentStreak,
    required this.longestStreak,
    required this.week,
    required this.memberCount,
    required this.completedTodayCount,
    required this.members,
  });

  double get todayProgress =>
      memberCount == 0 ? 0 : completedTodayCount / memberCount;

  int get remainingToday => memberCount - completedTodayCount;
}

/// The signed-in user's own streak numbers, shown on Profile.
class UserStreakStats {
  final int currentStreak;
  final int longestStreak;

  /// Booleans for Mon..Sun of the current week.
  final List<bool> week;
  final int todayIndex;

  const UserStreakStats({
    required this.currentStreak,
    required this.longestStreak,
    required this.week,
    required this.todayIndex,
  });

  int get activeDaysThisWeek => week.where((d) => d).length;

  static const empty = UserStreakStats(
    currentStreak: 0,
    longestStreak: 0,
    week: [false, false, false, false, false, false, false],
    todayIndex: 0,
  );
}
