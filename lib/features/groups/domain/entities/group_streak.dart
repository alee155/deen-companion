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
