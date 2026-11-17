import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/app_toast.dart';
import '../../auth/presentation/providers/auth_session_provider.dart';
import '../../groups/presentation/providers/groups_providers.dart';
import '../domain/snap_availability.dart';
import 'providers/snap_providers.dart';
import 'snap_availability_message.dart';

/// What every camera button does when tapped.
///
/// If a snap can't be sent right now it says why, in a toast, and goes no
/// further (so nobody takes a photo they can't send). Otherwise it opens the
/// snap flow and, on return, confirms what was sent.
///
/// [groupId] preselects a group in the flow (the group's own camera button);
/// without it the user chooses the groups. A group that already has your snap
/// for this prayer, or has no one else in it, is said so and not opened.
/// [availability] overrides the
/// prayer-based answer, for a screen that knows more (the groups list knows
/// whether there are any groups at all).
Future<void> openSnapFlow(
  BuildContext context,
  WidgetRef ref, {
  String? groupId,
  SnapAvailability? availability,
}) async {
  final SnapAvailability answer =
      availability ?? ref.read(snapAvailabilityProvider);
  final message = answer.message;
  if (message != null) {
    HapticFeedback.lightImpact();
    showAppToast(context, message, icon: Icons.info_outline_rounded);
    return;
  }

  if (groupId != null) {
    final why = ref.read(groupSnapBlockProvider(groupId));
    if (why != null) {
      HapticFeedback.lightImpact();
      showAppToast(context, why, icon: Icons.info_outline_rounded);
      return;
    }
  }

  HapticFeedback.selectionClick();
  final sentTo = await context.push<int>(
    groupId == null ? '/snap' : '/groups/$groupId/snap',
  );
  if (sentTo == null || !context.mounted) return;
  showAppToast(
    context,
    sentTo == 1 ? 'Snap sent' : 'Snap sent to $sentTo groups',
    icon: Icons.check_circle_rounded,
  );
}

/// Keeps what the bottom bar's camera button decides from loaded while the bar
/// is on screen, so a tap is answered at once instead of "still checking".
/// Watch it from the shell. Its value never changes, so it rebuilds nothing.
final snapNavReadyProvider = Provider<void>((ref) {
  if (!ref.watch(authSessionProvider.select((s) => s.isAuthenticated))) return;
  ref.watch(snapAvailabilityProvider);
  ref.watch(myGroupsProvider);
});

/// The camera button in the bottom bar. Guests are sent to sign up first
/// (snaps go to groups, and groups need an account) and come back to Home;
/// someone with no groups is told so; otherwise it is [openSnapFlow].
Future<void> openSnapFromNav(BuildContext context, WidgetRef ref) async {
  if (!ref.read(authSessionProvider).isAuthenticated) {
    HapticFeedback.selectionClick();
    context.push('/signup?redirect=${Uri.encodeQueryComponent('/')}');
    return;
  }
  final groups = ref.read(myGroupsProvider).valueOrNull;
  final availability = groups != null && groups.isEmpty
      ? const SnapAvailability.noGroups()
      : ref.read(snapAvailabilityProvider);
  await openSnapFlow(context, ref, availability: availability);
}
