import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/grouped_settings_tile.dart';

/// TEMPORARY Phase-1 validation harness for the native alarm pipeline —
/// exercises pushSchedule end-to-end without any of the real settings
/// UI/data model from later phases. Delete this whole file (and its one
/// call site in settings_screen.dart) once the real Prayer Reminders
/// settings screen lands.
class PrayerAlarmDebugHarness extends StatelessWidget {
  const PrayerAlarmDebugHarness({super.key});

  static const _channel = MethodChannel(
    'com.devsouq.deen_companion.app/prayer_alarms',
  );

  Future<void> _fireTestAlarm(BuildContext context) async {
    await Permission.notification.request();

    final canFullScreen =
        await _channel.invokeMethod<bool>('checkFullScreenIntentPermission') ??
        true;
    if (!canFullScreen) {
      await _channel.invokeMethod('openFullScreenIntentSettings');
    }

    final ignoringBattery =
        await _channel.invokeMethod<bool>('checkIgnoreBatteryOptimizations') ??
        false;
    if (!ignoringBattery) {
      await _channel.invokeMethod('requestIgnoreBatteryOptimizations');
    }

    final triggerAt = DateTime.now().add(const Duration(seconds: 70));
    await _channel.invokeMethod('pushSchedule', {
      'entries': [
        {
          'prayerName': 'fajr',
          'reminderType': 'atTime',
          'epochMillis': triggerAt.millisecondsSinceEpoch,
          'label': 'Test alarm — Fajr',
        },
      ],
      'snoozeMinutes': 10,
    });

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.emeraldInk,
        content: Text(
          'Test alarm armed for ${TimeOfDay.fromDateTime(triggerAt).format(context)} '
          '(~70s from now) — background or kill the app now.',
          style: TextStyle(color: AppColors.surfaceLight),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 24.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Debug — Prayer Alarms',
            style: AppTypography.titleMedium.copyWith(color: AppColors.error),
          ),
          SizedBox(height: 12.h),
          GroupedCard(
            children: [
              GroupedTile(
                icon: Icons.science_outlined,
                iconColor: AppColors.error,
                iconBg: AppColors.error.withValues(alpha: 0.12),
                title: 'Fire test alarm in ~70s',
                subtitle: 'Requests permissions, then arms one native alarm',
                onTap: () => _fireTestAlarm(context),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
