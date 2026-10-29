import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../shared/widgets/app_toast.dart';
import '../../prayer_logs/domain/prayer_log.dart';
import 'widgets/add_groups_sheet.dart';

/// "Send to more groups" on your own logged snap: opens the group list and
/// confirms what happened in a toast.
Future<void> openAddGroups(
  BuildContext context, {
  required PrayerLog log,
}) async {
  HapticFeedback.selectionClick();
  final result = await showAddGroupsSheet(context, log: log);
  if (result == null || !context.mounted) return;
  switch (result) {
    case AddedToGroups(:final count):
      showAppToast(
        context,
        count == 1
            ? 'Snap added to 1 more group'
            : 'Snap added to $count more groups',
        icon: Icons.check_circle_rounded,
      );
    case SnapExpiredResult():
      showAppToast(
        context,
        'This snap has expired, so it can’t be sent to more groups.',
        icon: Icons.info_outline_rounded,
      );
  }
}
