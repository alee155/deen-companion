import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/location/location_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/logger.dart';

/// Asked once, on the way in: the two permissions the app's time- and
/// place-sensitive features depend on, each with the reason it's needed.
///
/// A hard gate — the Continue button only appears once both Location and
/// Notifications are granted, so the app can't be entered in a state where
/// prayer times, Qibla, and reminders are silently broken.
class PermissionGateScreen extends ConsumerStatefulWidget {
  const PermissionGateScreen({super.key});

  @override
  ConsumerState<PermissionGateScreen> createState() =>
      _PermissionGateScreenState();
}

class _PermissionGateScreenState extends ConsumerState<PermissionGateScreen>
    with WidgetsBindingObserver {
  bool _locationGranted = false;
  bool _locationServiceEnabled = true;
  bool _locationBlocked = false;
  bool _notificationsGranted = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshStatuses();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Covers the round trip to system settings.
    if (state == AppLifecycleState.resumed) _refreshStatuses();
  }

  Future<void> _refreshStatuses() async {
    final availability = await ref
        .read(locationServiceProvider)
        .checkAvailability();
    var notificationsGranted = false;
    try {
      notificationsGranted = await Permission.notification.isGranted;
    } catch (error) {
      AppLogger.e('Notification permission check failed', error);
    }

    if (!mounted) return;
    setState(() {
      _locationGranted = availability.hasPermission;
      _locationServiceEnabled = availability.serviceEnabled;
      _locationBlocked = availability.permanentlyDenied;
      _notificationsGranted = notificationsGranted;
    });
  }

  Future<void> _handleLocation() async {
    if (_busy) return;
    setState(() => _busy = true);
    final service = ref.read(locationServiceProvider);

    try {
      if (_locationBlocked) {
        await service.openAppSettings();
      } else if (!_locationServiceEnabled) {
        await service.openLocationSettings();
      } else {
        await service.requestPermission();
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }

    ref.invalidate(locationAvailabilityProvider);
    await _refreshStatuses();
  }

  Future<void> _handleNotifications() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final status = await Permission.notification.request();
      if (status.isPermanentlyDenied) await openAppSettings();
    } catch (error) {
      AppLogger.e('Notification permission request failed', error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    await _refreshStatuses();
  }

  Future<void> _continue() async {
    await ref
        .read(localStorageServiceProvider)
        .put(
          AppConstants.settingsBoxName,
          AppConstants.permissionFlowSeenKey,
          true,
        );

    // Anything that was resolved while this screen was open should be
    // re-read now rather than on the next cold start.
    ref.invalidate(locationAvailabilityProvider);

    if (!mounted) return;
    context.go('/');
  }

  String get _locationStatusLabel {
    if (_locationGranted && _locationServiceEnabled) return 'Allowed';
    if (!_locationServiceEnabled) return 'Location Services off';
    if (_locationBlocked) return 'Blocked in settings';
    return 'Not allowed yet';
  }

  String get _locationActionLabel {
    if (_locationBlocked) return 'Open app settings';
    if (!_locationServiceEnabled) return 'Open location settings';
    return 'Allow location';
  }

  @override
  Widget build(BuildContext context) {
    final allSet =
        _locationGranted && _locationServiceEnabled && _notificationsGranted;

    return Scaffold(
      backgroundColor: AppColors.parchment,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 12.h),
              Text(
                'Before we begin',
                style: AppTypography.heroSerif.copyWith(
                  color: AppColors.inkText,
                  fontSize: 26.sp,
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                'Two permissions keep prayer times, Qibla, and reminders '
                'accurate for where you are. You can change either one later '
                'in Settings.',
                style: AppTypography.bodyLarge.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              SizedBox(height: 24.h),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    _PermissionCard(
                      icon: Icons.my_location_rounded,
                      accent: AppColors.hijriAccent,
                      accentBg: AppColors.hijriAccentBg,
                      title: 'Location',
                      why:
                          'Prayer times and the Qibla direction are calculated '
                          'from your coordinates. Without it, timings default '
                          'to nothing at all — we never guess a city for you.',
                      statusLabel: _locationStatusLabel,
                      isGranted: _locationGranted && _locationServiceEnabled,
                      actionLabel: _locationActionLabel,
                      onAction: _handleLocation,
                    ),
                    SizedBox(height: 14.h),
                    _PermissionCard(
                      icon: Icons.notifications_active_outlined,
                      accent: AppColors.worshipAccent,
                      accentBg: AppColors.worshipAccentBg,
                      title: 'Notifications',
                      why:
                          'Needed only for prayer reminders — the adhan alert '
                          'at each prayer time. Nothing else sends you a '
                          'notification.',
                      statusLabel: _notificationsGranted
                          ? 'Allowed'
                          : 'Not allowed yet',
                      isGranted: _notificationsGranted,
                      actionLabel: 'Allow notifications',
                      onAction: _handleNotifications,
                    ),
                  ],
                ),
              ),
              SizedBox(height: 8.h),
              if (allSet)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _continue,
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 14.h),
                    ),
                    child: const Text('Continue'),
                  ),
                )
              else
                Padding(
                  padding: EdgeInsets.only(top: 4.h),
                  child: Text(
                    'Allow both permissions above to continue.',
                    textAlign: TextAlign.center,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
              SizedBox(height: 8.h),
            ],
          ),
        ),
      ),
    );
  }
}

class _PermissionCard extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final Color accentBg;
  final String title;
  final String why;
  final String statusLabel;
  final bool isGranted;
  final String actionLabel;
  final VoidCallback onAction;

  const _PermissionCard({
    required this.icon,
    required this.accent,
    required this.accentBg,
    required this.title,
    required this.why,
    required this.statusLabel,
    required this.isGranted,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.borderWarm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42.w,
                height: 42.w,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accentBg,
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Icon(icon, color: accent, size: 20.sp),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.headline.copyWith(
                        fontSize: 15.sp,
                        color: AppColors.inkText,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      statusLabel,
                      style: AppTypography.caption.copyWith(
                        color: isGranted
                            ? AppColors.success
                            : AppColors.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (isGranted)
                Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.success,
                  size: 22.sp,
                ),
            ],
          ),
          SizedBox(height: 10.h),
          Text(
            why,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          if (!isGranted) ...[
            SizedBox(height: 12.h),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onAction,
                style: OutlinedButton.styleFrom(
                  foregroundColor: accent,
                  side: BorderSide(color: accent),
                ),
                child: Text(actionLabel),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
