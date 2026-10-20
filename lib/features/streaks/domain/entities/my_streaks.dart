import 'package:equatable/equatable.dart';

import '../../../prayer_times/domain/entities/prayer_times.dart';

/// The signed-in user's streak in one of their groups.
class GroupStreakSummary extends Equatable {
  final String groupId;
  final String name;
  final int currentStreak;
  final int bestStreak;

  /// What that group asks of a day, so the user knows what counts.
  final int minPrayers;

  const GroupStreakSummary({
    required this.groupId,
    required this.name,
    required this.currentStreak,
    required this.bestStreak,
    required this.minPrayers,
  });

  @override
  List<Object?> get props => [
    groupId,
    name,
    currentStreak,
    bestStreak,
    minPrayers,
  ];
}

/// Consecutive days one prayer has been logged, across all history and
/// regardless of any group's rule.
class PrayerStreak extends Equatable {
  final int currentStreak;
  final int bestStreak;
  const PrayerStreak({required this.currentStreak, required this.bestStreak});

  static const none = PrayerStreak(currentStreak: 0, bestStreak: 0);

  @override
  List<Object?> get props => [currentStreak, bestStreak];
}

/// The caller's streaks: one per group, and one per prayer.
class MyStreaks extends Equatable {
  final List<GroupStreakSummary> groups;
  final Map<PrayerName, PrayerStreak> prayers;

  const MyStreaks({required this.groups, required this.prayers});

  static const empty = MyStreaks(groups: [], prayers: {});

  PrayerStreak prayer(PrayerName p) => prayers[p] ?? PrayerStreak.none;

  /// The longest streak running right now in any group.
  int get currentBest =>
      groups.fold(0, (m, g) => g.currentStreak > m ? g.currentStreak : m);

  /// The longest streak ever reached in any group.
  int get longest =>
      groups.fold(0, (m, g) => g.bestStreak > m ? g.bestStreak : m);

  /// The group that streak is in, or null with no groups.
  GroupStreakSummary? get leading {
    GroupStreakSummary? best;
    for (final g in groups) {
      if (best == null || g.currentStreak > best.currentStreak) best = g;
    }
    return best;
  }

  /// True when there is nothing to show yet (no groups, no prayer streaks).
  bool get isBlank =>
      groups.isEmpty &&
      prayers.values.every((p) => p.currentStreak == 0 && p.bestStreak == 0);

  @override
  List<Object?> get props => [groups, prayers];
}
