import 'package:equatable/equatable.dart';

import '../../../groups/domain/entities/group.dart';

/// One member's line on a group's streak board.
class MemberStreak extends Equatable {
  final String userId;
  final String name;
  final GroupRole role;
  final int currentStreak;
  final int bestStreak;

  /// Distinct prayers logged today, and how many today needs to qualify.
  final int todayCount;
  final int todayRequired;
  final bool todayQualified;

  const MemberStreak({
    required this.userId,
    required this.name,
    required this.role,
    required this.currentStreak,
    required this.bestStreak,
    required this.todayCount,
    required this.todayRequired,
    required this.todayQualified,
  });

  /// Today's progress toward the goal, 0..1.
  double get todayProgress =>
      todayRequired <= 0 ? 1 : (todayCount / todayRequired).clamp(0.0, 1.0);

  @override
  List<Object?> get props => [
    userId,
    name,
    role,
    currentStreak,
    bestStreak,
    todayCount,
    todayRequired,
    todayQualified,
  ];
}

/// A group's streak board, in the server's order (longest current streak
/// first).
class GroupStreakBoard extends Equatable {
  final List<MemberStreak> entries;
  const GroupStreakBoard(this.entries);

  bool get isEmpty => entries.isEmpty;

  /// The entry for [userId], or null when they are not on the board.
  MemberStreak? of(String? userId) {
    if (userId == null) return null;
    for (final e in entries) {
      if (e.userId == userId) return e;
    }
    return null;
  }

  int get doneToday => entries.where((e) => e.todayQualified).length;

  /// What a day needs, read off the board (every row carries it); null when
  /// the board is empty.
  int? get required => entries.isEmpty ? null : entries.first.todayRequired;

  @override
  List<Object?> get props => [entries];
}
