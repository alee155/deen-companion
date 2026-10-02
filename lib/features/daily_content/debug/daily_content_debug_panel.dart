import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/error/failures.dart';
import '../../../core/usecase/usecase.dart';
import '../domain/entities/daily_content.dart';
import '../../../core/permissions/notification_permission_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../prayer_reminders/data/prayer_alarm_channel.dart';
import '../data/daily_content_store.dart';
import '../data/daily_notification_scheduler.dart';
import '../domain/daily_content_selector.dart';
import '../domain/notification_text.dart';
import '../presentation/providers/daily_content_providers.dart';

/// DEBUG-ONLY: fires the daily Ayat & Hadith notification after a custom
/// delay so the whole flow (arrive → tap → content screen → history entry)
/// can be tested without waiting for Fajr.
///
/// Isolated on purpose: it uses its own native entry point and its own
/// storage slot flagged `debug`, never touches the production schedule, and
/// is only ever built behind `kDebugMode` (the native side additionally
/// refuses the call on non-debuggable builds).
class DailyContentDebugPanel extends ConsumerStatefulWidget {
  const DailyContentDebugPanel({super.key});

  @override
  ConsumerState<DailyContentDebugPanel> createState() =>
      _DailyContentDebugPanelState();
}

class _DailyContentDebugPanelState
    extends ConsumerState<DailyContentDebugPanel> {
  String? _status;
  bool _busy = false;

  Future<void> _schedule(Duration delay) async {
    if (!kDebugMode || _busy) return;
    setState(() {
      _busy = true;
      _status = null;
    });
    try {
      final permission = ref.read(notificationPermissionServiceProvider);
      if (!await permission.isGranted()) await permission.request();

      final now = DateTime.now();
      final dateKey = DailyContentSelector.dateKey(now);
      final repository = ref.read(dailyContentRepositoryProvider);
      // Best-effort preview text; never let a slow network eat the delay.
      await repository
          .fetch(dateKey)
          .timeout(
            const Duration(seconds: 4),
            onTimeout: () => const Error(NetworkFailure()),
          )
          .catchError((_) => const Error<DailyContent>(UnexpectedFailure()));

      final at = DateTime.now().add(delay);
      final id = 'debug-${at.millisecondsSinceEpoch}';
      final armed = await ref
          .read(dailyNotificationSchedulerProvider)
          .scheduleDebug(
            DailyNotificationEntry(
              id: id,
              triggerAt: at,
              title: ref.read(dailyNotificationConfigProvider).title,
              body: DailyNotificationText.preview(
                repository.getCached(dateKey),
              ),
            ),
          );

      if (!armed) {
        _set('FAILED to schedule — see the console log.');
        return;
      }
      final store = ref.read(dailyContentStoreProvider);
      await store.writeSlots([
        ...store.readSlots().where((s) => !s.debug),
        NotificationSlot(
          id: id,
          dateKey: dateKey,
          epochMillis: at.millisecondsSinceEpoch,
          debug: true,
        ),
      ]);
      _set(
        'Scheduled via flutter_local_notifications for ${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}. '
        'Background the app / lock the screen, wait, then tap the notification.',
      );
    } catch (e) {
      _set('Failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _clear() async {
    if (!kDebugMode) return;
    await ref.read(dailyNotificationSchedulerProvider).cancelDebug();
    final store = ref.read(dailyContentStoreProvider);
    await store.writeSlots(store.readSlots().where((s) => !s.debug).toList());
    _set('Test notification cancelled.');
  }

  Future<void> _checkStatus() async {
    final allowed = await ref
        .read(notificationPermissionServiceProvider)
        .isGranted();
    final battery = await ref
        .read(prayerAlarmChannelProvider)
        .isIgnoringBatteryOptimizations();
    final pending = await ref
        .read(dailyNotificationSchedulerProvider)
        .pendingIds();
    final exact = await ref
        .read(dailyNotificationSchedulerProvider)
        .canScheduleExact();
    _set(
      'Notifications allowed: $allowed · Exact alarms: $exact · Battery-optimisation exempt: '
      '$battery · Pending: ${pending.length}',
    );
  }

  void _set(String message) {
    if (mounted) setState(() => _status = message);
  }

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) return const SizedBox.shrink();
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.borderWarm),
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'DEBUG · Daily Ayat & Hadith test',
            style: TextStyle(
              fontSize: 12.sp,
              fontWeight: FontWeight.w800,
              color: AppColors.textSecondary,
            ),
          ),
          SizedBox(height: 10.h),
          Wrap(
            spacing: 8.w,
            children: [
              for (final minutes in const [1, 2, 5])
                OutlinedButton(
                  onPressed: _busy
                      ? null
                      : () => _schedule(Duration(minutes: minutes)),
                  child: Text('In $minutes min'),
                ),
              TextButton(onPressed: _clear, child: const Text('Clear test')),
              TextButton(onPressed: _checkStatus, child: const Text('Status')),
              TextButton(
                onPressed: () => ref
                    .read(dailyNotificationSchedulerProvider)
                    .requestExactAlarmPermission(),
                child: const Text('Exact alarms'),
              ),
              TextButton(
                onPressed: () => ref
                    .read(prayerAlarmChannelProvider)
                    .requestIgnoreBatteryOptimizations(),
                child: const Text('Battery'),
              ),
            ],
          ),
          if (_status != null) ...[
            SizedBox(height: 8.h),
            Text(
              _status!,
              style: TextStyle(fontSize: 12.sp, color: AppColors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}
