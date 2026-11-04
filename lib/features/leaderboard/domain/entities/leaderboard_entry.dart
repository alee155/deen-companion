import 'package:equatable/equatable.dart';

import '../../../groups/domain/entities/group.dart';

/// One row of `GET /groups/{id}/leaderboard`.
///
/// Everything counts from the day the member joined this group, and [rank] is
/// the server's own (unique, so there are no ties to break here).
class LeaderboardEntry extends Equatable {
  final int rank;
  final String userId;
  final String name;
  final GroupRole role;
  final int points;
  final int prayersLogged;

  /// Consecutive qualifying days under the group's streak rule, ending today or
  /// yesterday.
  final int currentStreak;

  const LeaderboardEntry({
    required this.rank,
    required this.userId,
    required this.name,
    required this.role,
    required this.points,
    required this.prayersLogged,
    required this.currentStreak,
  });

  String get displayName => name.trim().isEmpty ? 'Member' : name.trim();

  String get initials {
    final parts = displayName.split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    final letters = parts.take(2).map((p) => p[0].toUpperCase()).join();
    return letters.isEmpty ? '?' : letters;
  }

  @override
  List<Object?> get props => [
    rank,
    userId,
    name,
    role,
    points,
    prayersLogged,
    currentStreak,
  ];
}
