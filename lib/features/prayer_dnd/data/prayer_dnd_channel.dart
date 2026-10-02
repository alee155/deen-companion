import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/logger.dart';
import '../domain/dnd_window.dart';

/// Dart side of the native prayer-DND pipeline (Android only). A missing
/// platform implementation degrades to "unavailable", never a crash.
class PrayerDndChannel {
  static const _channel = MethodChannel(
    'com.devsouq.deen_companion.app/prayer_dnd',
  );

  const PrayerDndChannel();

  /// Full cancel-and-replace of the armed windows. Returns how many the
  /// native side armed, or null if the platform couldn't be reached.
  Future<int?> pushSchedule(List<DndWindow> windows) => _invoke<int>(
    'pushSchedule',
    {'entries': windows.map((w) => w.toMap()).toList()},
  );

  Future<void> cancelAll() => _invoke<void>('cancelAll');

  /// Notification Policy access — the special permission Android requires
  /// before an app may change Do Not Disturb. Granted in system settings.
  Future<bool> hasPolicyAccess() async =>
      await _invoke<bool>('hasPolicyAccess') ?? false;

  Future<void> openPolicyAccessSettings() =>
      _invoke<void>('openPolicyAccessSettings');

  Future<bool> canScheduleExactAlarms() async =>
      await _invoke<bool>('canScheduleExactAlarms') ?? true;

  Future<void> openExactAlarmSettings() =>
      _invoke<void>('openExactAlarmSettings');

  Future<T?> _invoke<T>(String method, [Object? arguments]) async {
    try {
      return await _channel.invokeMethod<T>(method, arguments);
    } on MissingPluginException {
      return null;
    } catch (error, stackTrace) {
      AppLogger.e('Prayer DND channel "$method" failed', error, stackTrace);
      return null;
    }
  }
}

final prayerDndChannelProvider = Provider<PrayerDndChannel>(
  (ref) => const PrayerDndChannel(),
);
