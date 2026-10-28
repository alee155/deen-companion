import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/app_toast.dart';
import '../domain/entities/blocked_user.dart';
import '../domain/entities/report_target.dart';
import 'providers/moderation_providers.dart';
import 'widgets/block_sheet.dart';
import 'widgets/report_sheet.dart';
import 'widgets/user_actions_sheet.dart';

/// Someone another user can report or block: a person in a group, or the
/// sender of a snap.
class SafetyUser {
  final String id;
  final String name;
  final String? avatarUrl;
  const SafetyUser({required this.id, required this.name, this.avatarUrl});

  BlockedUser toBlocked() => BlockedUser(
    userId: id,
    name: name,
    avatarUrl: avatarUrl,
    blockedAt: DateTime.now(),
  );
}

/// The one place the report and block journeys are put together, so every
/// entry point (a member's menu, a snap's menu) behaves the same.

/// Opens the actions for [user] and carries out whichever the user picks.
Future<void> showUserSafetyActions(
  BuildContext context,
  WidgetRef ref, {
  required SafetyUser user,
}) async {
  final isBlocked = ref.read(blockedUserIdsProvider).contains(user.id);
  final action = await showUserActionsSheet(
    context,
    user: user,
    isBlocked: isBlocked,
  );
  if (action == null || !context.mounted) return;
  switch (action) {
    case UserAction.report:
      await startReport(
        context,
        ref,
        ReportUserTarget(userId: user.id, userName: user.name),
        avatarUrl: user.avatarUrl,
      );
    case UserAction.block:
      await startBlock(context, ref, user);
    case UserAction.unblock:
      await startUnblock(context, ref, user);
  }
}

/// Reports [target]. Afterwards a toast confirms it; if the user asked to block
/// the person too, that follows.
Future<void> startReport(
  BuildContext context,
  WidgetRef ref,
  ReportTarget target, {
  String? avatarUrl,
}) async {
  final outcome = await showReportSheet(
    context,
    target: target,
    alreadyBlocked: ref.read(blockedUserIdsProvider).contains(target.userId),
  );
  if (outcome == null || outcome == ReportOutcome.cancelled) return;
  if (!context.mounted) return;
  if (outcome == ReportOutcome.sentAndBlock) {
    await startBlock(
      context,
      ref,
      SafetyUser(
        id: target.userId,
        name: target.userName,
        avatarUrl: avatarUrl,
      ),
    );
  }
}

/// Asks the user to confirm, then blocks [user].
Future<void> startBlock(
  BuildContext context,
  WidgetRef ref,
  SafetyUser user,
) async {
  final blocked = await showBlockSheet(context, user: user);
  if (blocked != true || !context.mounted) return;
  showAppToast(
    context,
    '${user.name} is blocked. You can unblock them in Settings.',
    icon: Icons.block_rounded,
  );
}

/// Unblocks [user] straight away (nothing to confirm: it undoes a choice the
/// user made).
Future<void> startUnblock(
  BuildContext context,
  WidgetRef ref,
  SafetyUser user,
) async {
  final result = await ref.read(blockedUsersProvider.notifier).unblock(user.id);
  if (!context.mounted) return;
  result.when(
    success: (_) => showAppToast(
      context,
      '${user.name} is unblocked.',
      icon: Icons.check_circle_rounded,
    ),
    failure: (f) => showAppToast(context, f.message),
  );
}
