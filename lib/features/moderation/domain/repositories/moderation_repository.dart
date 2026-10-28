import '../../../../core/usecase/usecase.dart';
import '../entities/blocked_user.dart';
import '../entities/report_reason.dart';
import '../entities/report_target.dart';

/// Reporting and blocking.
///
/// Today this is [LocalModerationRepository]: blocks are kept on the device,
/// and a report is accepted without being sent anywhere, because the backend
/// endpoints don't exist yet. An API-backed implementation replaces it without
/// touching the screens.
abstract class ModerationRepository {
  /// Tells the team about [target]. [details] is the user's optional note.
  Future<Result<void>> report({
    required ReportTarget target,
    required ReportReason reason,
    String? details,
  });

  Future<Result<List<BlockedUser>>> getBlockedUsers();

  Future<Result<void>> blockUser(BlockedUser user);

  Future<Result<void>> unblockUser(String userId);
}
