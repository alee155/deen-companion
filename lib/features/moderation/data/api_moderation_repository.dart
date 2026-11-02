import '../../../core/error/exceptions.dart';
import '../../../core/error/failures.dart';
import '../../../core/usecase/usecase.dart';
import '../../../core/utils/flow_log.dart';
import '../../../core/utils/logger.dart';
import '../domain/entities/blocked_user.dart';
import '../domain/entities/report_reason.dart';
import '../domain/entities/report_target.dart';
import '../domain/repositories/moderation_repository.dart';
import 'moderation_remote_datasource.dart';

const _tag = 'MODERATION';

/// Reports and blocks through the API. A report reaches the team (stored and
/// emailed); a block hides the person's snaps in both directions and follows
/// the account to any phone.
class ApiModerationRepository implements ModerationRepository {
  final ModerationRemoteDataSource remote;
  const ApiModerationRepository(this.remote);

  @override
  Future<Result<void>> report({
    required ReportTarget target,
    required ReportReason reason,
    String? details,
  }) {
    final (type, id, groupId) = switch (target) {
      ReportUserTarget() => ('user', target.userId, null),
      ReportSnapTarget(:final snapId, :final groupId) => (
        'snap',
        snapId,
        groupId,
      ),
    };
    return _guard(
      'report $type',
      () => remote.report(
        targetType: type,
        targetId: id,
        reason: reason.apiValue,
        groupId: groupId,
        details: details,
      ),
    );
  }

  @override
  Future<Result<List<BlockedUser>>> getBlockedUsers() =>
      _guard('getBlocked', remote.getBlocked);

  @override
  Future<Result<void>> blockUser(BlockedUser user) =>
      _guard('block', () => remote.block(user.userId));

  @override
  Future<Result<void>> unblockUser(String userId) =>
      _guard('unblock', () => remote.unblock(userId));

  Future<Result<T>> _guard<T>(String op, Future<T> Function() body) async {
    try {
      final data = await body();
      FlowLog.log(_tag, '$op OK');
      return Success(data);
    } on NetworkException {
      return const Error(NetworkFailure());
    } on ServerException catch (e) {
      FlowLog.error(_tag, '$op: SERVER ERROR', '${e.statusCode} ${e.code}');
      return Error(ServerFailure(_message(e)));
    } catch (e, st) {
      AppLogger.e('ModerationRepository: $op failed', e, st);
      return const Error(UnexpectedFailure());
    }
  }

  /// What to tell the user for a server error. Codes first, then the status;
  /// anything else keeps the server's own message.
  static String _message(ServerException e) {
    switch (e.code) {
      case 'CANNOT_REPORT_SELF':
        return 'You can’t report yourself.';
      case 'CANNOT_BLOCK_SELF':
        return 'You can’t block yourself.';
      case 'USER_NOT_FOUND':
        return 'This person is no longer available.';
      case 'SNAP_NOT_FOUND':
        return 'This snap is no longer available.';
    }
    if (e.statusCode == 429) {
      return 'Too many requests. Please wait a minute and try again.';
    }
    return e.message ?? const ServerFailure().message;
  }
}
