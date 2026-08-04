import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/logger.dart';

/// One scheduled reminder, as the native side expects it.
class PrayerAlarmEntry {
  final String prayerName;
  final DateTime triggerAt;
  final String label;

  /// "atTime" or "before" — the native layer uses it only for labelling.
  final String reminderType;

  const PrayerAlarmEntry({
    required this.prayerName,
    required this.triggerAt,
    required this.label,
    this.reminderType = 'atTime',
  });

  Map<String, Object?> toMap() => {
    'prayerName': prayerName,
    'reminderType': reminderType,
    'epochMillis': triggerAt.millisecondsSinceEpoch,
    'label': label,
  };
}

/// Dart side of the native prayer-alarm pipeline.
///
/// Every call is wrapped: the channel is Android-only and a missing platform
/// implementation must degrade to "reminders unavailable", never crash the
/// screen that called it.
class PrayerAlarmChannel {
  static const _channel = MethodChannel(
    'com.devsouq.deen_companion.app/prayer_alarms',
  );

  const PrayerAlarmChannel();

  /// Full cancel-and-replace of the armed schedule. Returns how many alarms
  /// the native side armed, or null if the platform couldn't be reached.
  Future<int?> pushSchedule(
    List<PrayerAlarmEntry> entries, {
    int snoozeMinutes = 10,
  }) async {
    return _invoke<int>('pushSchedule', {
      'entries': entries.map((e) => e.toMap()).toList(),
      'snoozeMinutes': snoozeMinutes,
    });
  }

  Future<void> cancelAll() => _invoke<void>('cancelAllAlarms');

  Future<bool> notificationsEnabled() async =>
      await _invoke<bool>('requestNotificationPermission') ?? false;

  Future<bool> canUseFullScreenIntent() async =>
      await _invoke<bool>('checkFullScreenIntentPermission') ?? true;

  Future<void> openFullScreenIntentSettings() =>
      _invoke<void>('openFullScreenIntentSettings');

  Future<bool> isIgnoringBatteryOptimizations() async =>
      await _invoke<bool>('checkIgnoreBatteryOptimizations') ?? true;

  Future<void> requestIgnoreBatteryOptimizations() =>
      _invoke<void>('requestIgnoreBatteryOptimizations');

  Future<T?> _invoke<T>(String method, [Object? arguments]) async {
    try {
      return await _channel.invokeMethod<T>(method, arguments);
    } on MissingPluginException {
      // iOS, or a platform build without the alarm module.
      return null;
    } catch (error, stackTrace) {
      AppLogger.e('Prayer alarm channel "$method" failed', error, stackTrace);
      return null;
    }
  }
}

final prayerAlarmChannelProvider = Provider<PrayerAlarmChannel>((ref) {
  return const PrayerAlarmChannel();
});
