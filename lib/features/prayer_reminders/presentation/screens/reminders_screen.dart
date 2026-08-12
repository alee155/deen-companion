import 'package:deen_companion/features/ads/presentation/widgets/banner_ad_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/logger.dart';
import '../../../../shared/widgets/deen_app_bar.dart';
import '../../data/prayer_alarm_channel.dart';
import '../providers/reminders_provider.dart';

/// Explains what prayer reminders do, then lets the user switch them on or
/// off. Enabling walks the permissions the feature actually needs (notifications,
/// full-screen alerts, battery exemption) and then arms the schedule, reporting
/// exactly what happened instead of silently flipping a switch.
class RemindersScreen extends ConsumerStatefulWidget {
  const RemindersScreen({super.key});

  @override
  ConsumerState<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends ConsumerState<RemindersScreen> {
  bool _busy = false;
  String? _statusMessage;
  bool _statusIsError = false;

  Future<void> _onToggle(bool enabled) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _statusMessage = null;
      _statusIsError = false;
    });

    final notifier = ref.read(remindersEnabledProvider.notifier);
    final service = ref.read(prayerReminderServiceProvider);

    try {
      if (!enabled) {
        await notifier.set(false);
        await service.cancelAll();
        _setStatus('Reminders turned off. No alarms are armed.', false);
        return;
      }

      final granted = await _ensurePermissions();
      if (!granted) {
        await notifier.set(false);
        _setStatus(
          'Notification permission is needed before reminders can be '
          'switched on.',
          true,
        );
        return;
      }

      await notifier.set(true);
      final result = await service.sync();
      switch (result) {
        case ReminderSyncScheduled(:final alarmCount, :final dayCount):
          _setStatus(
            'Reminders on — $alarmCount alarms armed for the next $dayCount '
            'days. They keep working with the app closed.',
            false,
          );
        case ReminderSyncFailed(:final message):
          await notifier.set(false);
          _setStatus(message, true);
        case ReminderSyncDisabled():
          break;
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _setStatus(String message, bool isError) {
    if (!mounted) return;
    setState(() {
      _statusMessage = message;
      _statusIsError = isError;
    });
  }

  /// Notifications are mandatory; the other two only affect *reliability*, so
  /// the user is offered them but not blocked on them.
  Future<bool> _ensurePermissions() async {
    final channel = ref.read(prayerAlarmChannelProvider);

    var notificationsGranted = false;
    try {
      final status = await Permission.notification.request();
      notificationsGranted = status.isGranted;
    } catch (error) {
      AppLogger.e('Notification permission request failed', error);
      // A platform that has no runtime notification permission (older
      // Android, iOS via the channel no-op) shouldn't be blocked.
      notificationsGranted = await channel.notificationsEnabled();
    }
    if (!notificationsGranted) return false;

    if (!await channel.canUseFullScreenIntent()) {
      await channel.openFullScreenIntentSettings();
    }
    if (!await channel.isIgnoringBatteryOptimizations()) {
      await channel.requestIgnoreBatteryOptimizations();
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final enabled = ref.watch(remindersEnabledProvider);

    return Scaffold(
      backgroundColor: AppColors.parchment,
      appBar: const DeenAppBar(title: 'Prayer Reminders'),
      body: ListView(
        padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 32.h),
        children: [
          Container(
            padding: EdgeInsets.all(18.w),
            decoration: BoxDecoration(
              color: AppColors.heroSurface,
              borderRadius: BorderRadius.circular(18.r),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.notifications_active_outlined,
                  color: AppColors.gold,
                  size: 26.sp,
                ),
                SizedBox(height: 10.h),
                Text(
                  'An alert at every prayer time',
                  style: AppTypography.headline.copyWith(
                    color: AppColors.onHeroSurface,
                    fontSize: 17.sp,
                  ),
                ),
                SizedBox(height: 6.h),
                Text(
                  'Deen arms a real alarm for each of the five daily prayers, '
                  'calculated for your location. It rings even if the app is '
                  'closed or the phone has been restarted.',
                  style: AppTypography.bodyLarge.copyWith(
                    color: AppColors.onHeroSurface.withValues(alpha: 0.82),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 20.h),

          Text(
            'How it works',
            style: AppTypography.titleMedium.copyWith(
              color: AppColors.inkText,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 12.h),
          const _InfoRow(
            icon: Icons.schedule,
            title: 'Follows your prayer times',
            body:
                'Reminders use the same calculation method and Asr school you '
                'set in Settings, for your current location.',
          ),
          const _InfoRow(
            icon: Icons.offline_bolt_outlined,
            title: 'Works offline',
            body:
                'A week of alarms is armed ahead of time, so reminders keep '
                'arriving without a connection.',
          ),
          const _InfoRow(
            icon: Icons.lock_clock,
            title: 'Rings over the lock screen',
            body:
                'The alert shows full-screen with the prayer name, and can be '
                'snoozed or dismissed from there.',
          ),
          const _InfoRow(
            icon: Icons.battery_saver,
            title: 'Needs a couple of Android permissions',
            body:
                'Notifications, permission to show full-screen alerts, and an '
                'exemption from battery optimisation otherwise Android may '
                'delay or drop an alarm.',
          ),

          SizedBox(height: 20.h),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(color: AppColors.borderWarm),
            ),
            child: SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: enabled,
              onChanged: _busy ? null : _onToggle,
              activeThumbColor: AppColors.emeraldInk,
              title: Text(
                'Prayer reminders',
                style: AppTypography.headline.copyWith(
                  fontSize: 15.sp,
                  color: AppColors.inkText,
                ),
              ),
              subtitle: Text(
                enabled ? 'On — alarms are armed' : 'Off',
                style: AppTypography.bodyMedium.copyWith(
                  color: enabled ? AppColors.success : AppColors.textMuted,
                ),
              ),
            ),
          ),

          if (_busy)
            Padding(
              padding: EdgeInsets.only(top: 16.h),
              child: Row(
                children: [
                  SizedBox(
                    width: 16.w,
                    height: 16.w,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.emeraldInk,
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Text(
                    'Setting up reminders…',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

          if (_statusMessage != null && !_busy)
            Padding(
              padding: EdgeInsets.only(top: 16.h),
              child: Container(
                padding: EdgeInsets.all(14.w),
                decoration: BoxDecoration(
                  color: _statusIsError
                      ? AppColors.hadithAccentBg
                      : AppColors.quranAccentBg,
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      _statusIsError
                          ? Icons.error_outline_rounded
                          : Icons.check_circle_outline_rounded,
                      size: 18.sp,
                      color: _statusIsError
                          ? AppColors.error
                          : AppColors.quranAccent,
                    ),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: Text(
                        _statusMessage!,
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.inkText,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const BannerAdWidget(margin: EdgeInsets.symmetric(vertical: 4)),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _InfoRow({required this.icon, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 14.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36.w,
            height: 36.w,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.worshipAccentBg,
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Icon(icon, size: 18.sp, color: AppColors.worshipAccent),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.titleMedium.copyWith(
                    color: AppColors.inkText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  body,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
