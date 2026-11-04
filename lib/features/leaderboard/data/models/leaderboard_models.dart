import '../../../groups/domain/entities/group.dart';
import '../../domain/entities/leaderboard_entry.dart';

/// The rows of a leaderboard answer, best first.
///
/// The server documents a bare array, but its other answers come wrapped as
/// `{success, data}`, so both are accepted. A row that is not the documented
/// shape throws a `TypeError`, which the data source turns into a server
/// failure rather than showing a half-empty board.
List<LeaderboardEntry> leaderboardFromJson(Object? body) {
  final rows = body is Map<String, dynamic> ? body['data'] : body;
  final entries = [
    for (final row in rows as List) _entry(row as Map<String, dynamic>),
  ];
  entries.sort((a, b) => a.rank.compareTo(b.rank));
  return entries;
}

LeaderboardEntry _entry(Map<String, dynamic> j) => LeaderboardEntry(
  rank: (j['rank'] as num).toInt(),
  userId: j['userId'] as String,
  name: (j['name'] as String?) ?? '',
  role: GroupRole.parse(j['role'] as String?),
  points: (j['points'] as num).toInt(),
  prayersLogged: (j['prayersLogged'] as num).toInt(),
  currentStreak: (j['currentStreak'] as num).toInt(),
);
