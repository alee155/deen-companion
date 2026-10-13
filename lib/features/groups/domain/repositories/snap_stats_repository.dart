import '../../../../core/usecase/usecase.dart';
import '../entities/member_snap_stats.dart';

/// Snap statistics for a group's members.
///
/// TODO(snaps-backend): the real API isn't ready. [MockSnapStatsRepository]
/// implements this today; swap the provider to a remote-backed
/// implementation later — presentation only depends on this contract.
abstract class SnapStatsRepository {
  Future<Result<GroupSnapOverview>> getGroupOverview({
    required String groupId,
    required List<String> memberIds,
  });
}
