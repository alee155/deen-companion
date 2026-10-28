import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/app_toast.dart';
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
/// without it the user chooses the groups. [availability] overrides the
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
