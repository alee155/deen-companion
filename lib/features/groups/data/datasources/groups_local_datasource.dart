import '../../domain/entities/group_streak.dart';

/// Mock personal streak numbers for Profile only — groups come from the API
/// ([GroupsRemoteDataSource]) and snap stats from [SnapStatsRepository].
///
/// TODO(groups-backend): replace when a streak API exists.
class GroupsLocalDataSource {
  /// Monday-first booleans for this week: every day before today is done.
  List<bool> _myWeek(int todayIndex) => [
    for (var i = 0; i < 7; i++) i < todayIndex,
  ];

  UserStreakStats myStats() {
    final todayIndex = DateTime.now().weekday - 1;
    return UserStreakStats(
      currentStreak: todayIndex + 7,
      longestStreak: todayIndex + 12,
      week: _myWeek(todayIndex),
      todayIndex: todayIndex,
    );
  }
}
