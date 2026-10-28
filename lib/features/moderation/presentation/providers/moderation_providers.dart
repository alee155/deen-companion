import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../auth/presentation/providers/auth_session_provider.dart';
import '../../data/local_moderation_repository.dart';
import '../../domain/entities/blocked_user.dart';
import '../../domain/entities/report_reason.dart';
import '../../domain/entities/report_target.dart';
import '../../domain/repositories/moderation_repository.dart';

/// Today a local stand-in; swap this one line for the API implementation when
/// the endpoints exist. Rebuilt when the account changes so each account sees
/// its own blocked list.
final moderationRepositoryProvider = Provider<ModerationRepository>((ref) {
  final userId = ref.watch(authSessionProvider.select((s) => s.userId));
  return LocalModerationRepository(
    storage: ref.watch(localStorageServiceProvider),
    ownerId: userId,
  );
});

/// The people the user has blocked, newest first.
class BlockedUsersNotifier extends AsyncNotifier<List<BlockedUser>> {
  @override
  Future<List<BlockedUser>> build() async {
    final result = await ref
        .watch(moderationRepositoryProvider)
        .getBlockedUsers();
    return result.when(success: (d) => d, failure: (f) => throw f);
  }

  /// Blocks [user]. On failure the list is left as it was and the failure is
  /// returned for the sheet to show.
  Future<Result<void>> block(BlockedUser user) async {
    final result = await ref.read(moderationRepositoryProvider).blockUser(user);
    if (result is Success<void>) {
      final others = [
        for (final b in state.valueOrNull ?? const <BlockedUser>[])
          if (b.userId != user.userId) b,
      ];
      state = AsyncData([user, ...others]);
    }
    return result;
  }

  Future<Result<void>> unblock(String userId) async {
    final result = await ref
        .read(moderationRepositoryProvider)
        .unblockUser(userId);
    if (result is Success<void>) {
      state = AsyncData([
        for (final b in state.valueOrNull ?? const <BlockedUser>[])
          if (b.userId != userId) b,
      ]);
    }
    return result;
  }
}

final blockedUsersProvider =
    AsyncNotifierProvider<BlockedUsersNotifier, List<BlockedUser>>(
      BlockedUsersNotifier.new,
    );

/// Ids of everyone blocked, for screens that only need to ask "is this person
/// blocked?". Empty until the list has loaded: nothing is hidden by mistake.
final blockedUserIdsProvider = Provider<Set<String>>(
  (ref) => {
    for (final b
        in ref.watch(blockedUsersProvider).valueOrNull ?? const <BlockedUser>[])
      b.userId,
  },
);

@immutable
class ReportState {
  final bool isSubmitting;
  final String? errorMessage;
  const ReportState({this.isSubmitting = false, this.errorMessage});
}

/// Sends one report from the report sheet.
class ReportController extends AutoDisposeNotifier<ReportState> {
  @override
  ReportState build() => const ReportState();

  /// True once the report was accepted.
  Future<bool> submit({
    required ReportTarget target,
    required ReportReason reason,
    String? details,
  }) async {
    if (state.isSubmitting) return false;
    state = const ReportState(isSubmitting: true);
    final trimmed = details?.trim();
    final result = await ref
        .read(moderationRepositoryProvider)
        .report(
          target: target,
          reason: reason,
          details: trimmed == null || trimmed.isEmpty ? null : trimmed,
        );
    return result.when(
      success: (_) {
        state = const ReportState();
        return true;
      },
      failure: (f) {
        state = ReportState(errorMessage: f.message);
        return false;
      },
    );
  }
}

final reportControllerProvider =
    NotifierProvider.autoDispose<ReportController, ReportState>(
      ReportController.new,
    );
