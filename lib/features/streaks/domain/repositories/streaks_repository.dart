import '../../../../core/usecase/usecase.dart';
import '../entities/group_streaks.dart';
import '../entities/my_streaks.dart';
import '../entities/streak_rule.dart';

/// Streaks are computed by the server from the prayer logs on every read, so
/// nothing here is cached: each call asks again.
abstract class StreaksRepository {
  /// `GET /groups/{id}/streak-rule` — any member.
  Future<Result<StreakRule>> getRule(String groupId);

  /// `PATCH /groups/{id}/streak-rule` — admin only. Returns the resulting
  /// rule (the current one, unchanged, when [minPrayers] is already in force).
  Future<Result<StreakRule>> setRule(String groupId, int minPrayers);

  /// `GET /groups/{id}/streaks` — the board, any member.
  Future<Result<GroupStreakBoard>> getBoard(String groupId);

  /// `GET /users/me/streaks` — the caller's group and per-prayer streaks.
  Future<Result<MyStreaks>> getMine();
}
