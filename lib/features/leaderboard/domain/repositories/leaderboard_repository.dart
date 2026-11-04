import '../../../../core/usecase/usecase.dart';
import '../entities/leaderboard_entry.dart';

/// Members only: the server answers `403` to someone outside the group and
/// `404` when the group does not exist.
abstract class LeaderboardRepository {
  /// `GET /groups/{id}/leaderboard` — ranked 1..n, best first.
  Future<Result<List<LeaderboardEntry>>> leaderboard(String groupId);
}
