import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/location/location_service.dart';
import '../../../../core/permissions/notification_permission_service.dart';
import '../../../../core/storage/local_storage_service.dart';
import '../../../../core/utils/logger.dart';
import '../../../daily_content/presentation/providers/daily_content_providers.dart';
import '../../../daily_content/presentation/providers/daily_notification_service.dart';
import '../../../prayer_reminders/data/prayer_alarm_channel.dart';
import '../../../prayer_reminders/presentation/providers/reminders_provider.dart';
import '../../domain/reliability_requirement.dart';

/// Checks and requests every permission reminders and notifications depend
/// on. One place, one order, one prompt at a time — Android drops a request
/// made while another dialog is on screen, so requests are never concurrent.
///
/// System-settings steps (alarms, full-screen, battery) return to the app via
/// a resume, so the service watches lifecycle both to re-check status and to
/// know when the user is back.
class ReliabilityService with WidgetsBindingObserver {
  final Ref ref;
  ReliabilityService(this.ref) {
    WidgetsBinding.instance.addObserver(this);
  }

  Completer<void>? _resumeWaiter;
  bool _running = false;

  bool get _isAndroid => defaultTargetPlatform == TargetPlatform.android;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    ref.invalidate(reliabilityStatusProvider);
    final waiter = _resumeWaiter;
    if (waiter != null && !waiter.isCompleted) waiter.complete();
  }

  void dispose() => WidgetsBinding.instance.removeObserver(this);

  Future<ReliabilityStatus> check() async {
    final location = await ref
        .read(locationServiceProvider)
        .checkAvailability();
    final notifications = await ref
        .read(notificationPermissionServiceProvider)
        .isGranted();

    // The remaining three are Android concepts (and answer "fine" where the
    // OS has no such gate: exact alarms before Android 12, full-screen
    // alerts before 14).
    var exact = true, fullScreen = true, battery = true;
    if (_isAndroid) {
      final alarm = ref.read(prayerAlarmChannelProvider);
      exact = await ref
          .read(dailyNotificationSchedulerProvider)
          .canScheduleExact();
      fullScreen = await alarm.canUseFullScreenIntent();
      battery = await alarm.isIgnoringBatteryOptimizations();
    }

    return {
      ReliabilityRequirement.location: location.hasPermission,
      ReliabilityRequirement.notifications: notifications,
      ReliabilityRequirement.exactAlarms: exact,
      ReliabilityRequirement.fullScreenAlerts: fullScreen,
      ReliabilityRequirement.batteryOptimization: battery,
    };
  }

  /// Asks for one requirement. Returns once the user is back in the app.
  Future<void> request(ReliabilityRequirement requirement) async {
    final alarm = ref.read(prayerAlarmChannelProvider);
    try {
      switch (requirement) {
        case ReliabilityRequirement.location:
          final result = await ref
              .read(locationServiceProvider)
              .requestPermission();
          if (result.permanentlyDenied) {
            await _viaSettings(
              ref.read(locationServiceProvider).openAppSettings,
            );
          }
        case ReliabilityRequirement.notifications:
          final permission = ref.read(notificationPermissionServiceProvider);
          final result = await permission.request();
          if (result == PermissionRequestResult.permanentlyDenied) {
            await _viaSettings(permission.openAppSettings);
          }
        case ReliabilityRequirement.exactAlarms:
          // Completes when the user returns from the system screen.
          await ref
              .read(dailyNotificationSchedulerProvider)
              .requestExactAlarmPermission();
        case ReliabilityRequirement.fullScreenAlerts:
          await _viaSettings(alarm.openFullScreenIntentSettings);
        case ReliabilityRequirement.batteryOptimization:
          await _viaSettings(alarm.requestIgnoreBatteryOptimizations);
      }
    } catch (error, stackTrace) {
      AppLogger.e(
        'Reliability request ${requirement.name} failed',
        error,
        stackTrace,
      );
    }
    ref.invalidate(reliabilityStatusProvider);
  }

  /// Opens a system screen and waits for the user to come back (bounded, so a
  /// missed resume can never wedge the flow).
  Future<void> _viaSettings(Future<void> Function() open) async {
    _resumeWaiter = Completer<void>();
    await open();
    await _resumeWaiter!.future.timeout(
      const Duration(minutes: 5),
      onTimeout: () {},
    );
    _resumeWaiter = null;
  }

  /// Walks every missing requirement in order, one prompt at a time, then
  /// re-arms whatever was waiting on the new permissions. [onStep] reports
  /// which requirement is currently being asked.
  Future<void> setUpAll({
    void Function(ReliabilityRequirement?)? onStep,
  }) async {
    if (_running) return;
    _running = true;
    try {
      for (final requirement in ReliabilityRequirement.values) {
        final status = await check();
        if (status[requirement] ?? true) continue;
        onStep?.call(requirement);
        await request(requirement);
      }
    } finally {
      onStep?.call(null);
      _running = false;
    }
    await rearm();
  }

  /// Permissions changed: arm the daily notification (now exact if allowed)
  /// and refresh prayer alarms, so nothing waits for the next app launch.
  Future<void> rearm() async {
    await ref.read(dailyNotificationServiceProvider).sync();
    await ref.read(prayerReminderServiceProvider).syncIfEnabled();
  }

  // ── Upfront prompt cadence ─────────────────────────────────────────────

  static const _promptGap = Duration(hours: 24);

  /// Whether Home should open the setup sheet now: something is missing and
  /// the user hasn't just been shown it. A declined sheet isn't repeated for
  /// 24 hours (the Home banner stays as a standing reminder).
  bool shouldPrompt() {
    final raw = ref
        .read(localStorageServiceProvider)
        .get<int>(
          AppConstants.settingsBoxName,
          AppConstants.reliabilityPromptedAtKey,
        );
    if (raw == null) return true;
    return DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(raw)) >
        _promptGap;
  }

  Future<void> markPrompted() => ref
      .read(localStorageServiceProvider)
      .put(
        AppConstants.settingsBoxName,
        AppConstants.reliabilityPromptedAtKey,
        DateTime.now().millisecondsSinceEpoch,
      );
}

final reliabilityServiceProvider = Provider<ReliabilityService>((ref) {
  final service = ReliabilityService(ref);
  ref.onDispose(service.dispose);
  return service;
});

/// Live status of every requirement; invalidated on app resume and after any
/// request, so UI never shows a stale tick.
final reliabilityStatusProvider = FutureProvider<ReliabilityStatus>(
  (ref) => ref.read(reliabilityServiceProvider).check(),
);
