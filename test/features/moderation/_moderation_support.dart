import 'package:deen_companion/core/error/failures.dart';
import 'package:deen_companion/core/usecase/usecase.dart';
import 'package:deen_companion/features/moderation/domain/entities/blocked_user.dart';
import 'package:deen_companion/features/moderation/domain/entities/report_reason.dart';
import 'package:deen_companion/features/moderation/domain/entities/report_target.dart';
import 'package:deen_companion/features/moderation/domain/repositories/moderation_repository.dart';

BlockedUser blocked(String id, {String name = 'Someone', DateTime? at}) =>
    BlockedUser(
      userId: id,
      name: name,
      blockedAt: at ?? DateTime(2026, 10, 28, 12),
    );

/// A moderation back end the test controls: remembers what it was asked and
/// can be told to fail.
class FakeModeration implements ModerationRepository {
  final List<BlockedUser> list;
  Failure? failure;
  bool hold = false;

  final reports =
      <({ReportTarget target, ReportReason reason, String? details})>[];
  int blockCalls = 0;
  int unblockCalls = 0;

  FakeModeration([List<BlockedUser> initial = const []]) : list = [...initial];

  @override
  Future<Result<void>> report({
    required ReportTarget target,
    required ReportReason reason,
    String? details,
  }) async {
    if (hold) await Future<void>.delayed(const Duration(milliseconds: 500));
    if (failure != null) return Error(failure!);
    reports.add((target: target, reason: reason, details: details));
    return const Success(null);
  }

  @override
  Future<Result<List<BlockedUser>>> getBlockedUsers() async {
    if (failure != null) return Error(failure!);
    return Success([...list]);
  }

  @override
  Future<Result<void>> blockUser(BlockedUser user) async {
    blockCalls++;
    if (failure != null) return Error(failure!);
    list
      ..removeWhere((b) => b.userId == user.userId)
      ..insert(0, user);
    return const Success(null);
  }

  @override
  Future<Result<void>> unblockUser(String userId) async {
    unblockCalls++;
    if (failure != null) return Error(failure!);
    list.removeWhere((b) => b.userId == userId);
    return const Success(null);
  }
}
