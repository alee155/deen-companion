import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/usecase/usecase.dart';
import '../../../core/utils/flow_log.dart';
import '../../../shared/widgets/app_toast.dart';
import '../domain/prayer_log.dart';
import '../domain/prayer_log_failure.dart';
import 'providers/prayer_logs_providers.dart';
import 'widgets/snap_photo_viewer.dart';

/// Opens another member's snap, following the server's view-once rules:
///
/// * the link comes from `POST /prayers/logs/{id}/view`, once, never stored;
/// * a snap already opened, or past its window, only says so;
/// * after the viewer closes (timer end or dismissal) the snap counts as
///   opened here, and the feed is fetched again for the server's view.
///
/// The call is never repeated for the same log: a snap that was opened and
/// lost (app killed) is gone, as intended. Returns what the viewer's ⋯ menu
/// asked for, if anything.
Future<SnapViewerAction?> openMemberSnap(
  BuildContext context,
  WidgetRef ref, {
  required PrayerLog log,
  required String title,
  String? subtitle,
  Widget? avatar,
  bool canModerate = true,
}) async {
  const tag = 'SNAP VIEW';
  switch (log.snapState(DateTime.now())) {
    case SnapState.none:
      return null;
    case SnapState.opened:
      showAppToast(context, 'You’ve already opened this snap.');
      return null;
    case SnapState.expired:
      showAppToast(context, 'This snap has expired.');
      return null;
    case SnapState.unopened:
      break;
  }

  FlowLog.log(tag, 'ASKING THE SERVER TO OPEN SNAP ${log.id} (once)');
  final result = await ref.read(prayerLogsRepositoryProvider).viewSnap(log.id);
  if (!context.mounted) return null;

  void record(SnapState outcome) {
    ref
        .read(snapOutcomesProvider.notifier)
        .update((m) => {...m, log.id: outcome});
    ref.invalidate(groupPrayersProvider);
  }

  switch (result) {
    case Error(:final failure):
      final code = failure is PrayerLogFailure ? failure.code : null;
      if (code == PrayerLogErrorCode.snapAlreadyViewed) {
        record(SnapState.opened);
        showAppToast(context, 'You’ve already opened this snap.');
      } else if (code == PrayerLogErrorCode.snapExpired) {
        record(SnapState.expired);
        showAppToast(context, 'This snap has expired.');
      } else {
        // Nothing was consumed: a failed call can be tried again.
        showAppToast(
          context,
          'Couldn’t open this snap. Check your connection and try again.',
        );
      }
      FlowLog.log(tag, 'COULD NOT OPEN: ${failure.message}');
      return null;
    case Success(:final data):
      FlowLog.log(tag, 'OPENED - showing it once, nothing is saved');
      final action = await showSnapPhoto(
        context,
        url: data.url,
        title: title,
        subtitle: subtitle,
        avatar: avatar,
        duration: data.viewDurationSeconds == null
            ? log.viewDuration()
            : Duration(seconds: data.viewDurationSeconds!),
        canModerate: canModerate,
      );
      if (context.mounted) record(SnapState.opened);
      return action;
  }
}
