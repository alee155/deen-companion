import '../../../../core/usecase/usecase.dart';
import '../entities/group.dart';
import '../entities/group_detail.dart';
import '../entities/group_invite.dart';
import '../entities/invite_preview.dart';
import '../entities/group_streak.dart';

abstract class GroupsRepository {
  Future<Result<List<Group>>> getMyGroups();
  Future<Result<Group>> createGroup(NewGroup input);
  Future<Result<GroupDetail>> getGroupDetail(String groupId);

  /// Admin only (enforced by the backend). Changes name and description.
  Future<Result<Group>> updateGroup(
    String groupId, {
    required String name,
    required String description,
  });

  /// Admin only (enforced by the backend).
  Future<Result<void>> deleteGroup(String groupId);

  /// The group's current invite link.
  Future<Result<GroupInvite>> getInvite(String groupId);

  /// Replaces the invite link; the old one stops working.
  Future<Result<GroupInvite>> resetInvite(String groupId);

  /// Admin only (enforced by the backend). The admin can't remove themself —
  /// they must [leaveGroup].
  Future<Result<void>> removeMember(String groupId, String userId);

  /// Leaves the group. If the admin leaves, the next member becomes admin; if
  /// the last member leaves, the group is deleted.
  Future<Result<void>> leaveGroup(String groupId);

  /// What an invite link points at (works without login).
  Future<Result<InvitePreview>> previewInvite(String token);

  /// Joins the group behind [token]. Safe to repeat.
  Future<Result<JoinResult>> joinGroup(String token);

  /// Still a local mock (Profile streak card) — no streak API yet.
  Future<Result<UserStreakStats>> getMyStreakStats();
}
