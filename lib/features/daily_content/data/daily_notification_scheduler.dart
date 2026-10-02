import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../core/utils/logger.dart';

/// One notification to schedule. [id] doubles as the tap payload, so a tap
/// can be mapped back to the day it belongs to.
class DailyNotificationEntry {
  final String id;
  final DateTime triggerAt;
  final String title;
  final String body;

  const DailyNotificationEntry({
    required this.id,
    required this.triggerAt,
    required this.title,
    required this.body,
  });
}

/// Thin wrapper over `flutter_local_notifications` for the daily Ayat &
/// Hadith notification. The OS owns the schedule (the plugin registers
/// AlarmManager alarms and re-arms them after reboot), so delivery doesn't
/// depend on the Flutter app being alive. Prayer alarms stay on the native
/// alarm pipeline; this is only for plain notifications.
class DailyNotificationScheduler {
  DailyNotificationScheduler();

  static const _channelId = 'daily_content_v3';
  static const _channelName = 'Ayat & Hadith of the Day';
  static const _smallIcon = 'ic_stat_logo';

  /// Fixed id for the single debug-only test notification, far from any
  /// real id (real ids are the yyyyMMdd integer of the day).
  static const _debugNotificationId = 99000001;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  /// Call once at launch. [onTap] receives the payload (notification id) of
  /// a notification tapped while the process is alive.
  Future<void> init({required void Function(String id) onTap}) async {
    if (_initialized) return;
    _initialized = true;
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings(_smallIcon),
        ),
        onDidReceiveNotificationResponse: (response) {
          final payload = response.payload;
          if (payload != null) onTap(payload);
        },
      );
      // Channel importance / lock-screen visibility are fixed at creation,
      // so the earlier channel (created with weaker settings) is replaced.
      await _android?.deleteNotificationChannel(channelId: 'daily_content_v2');
    } catch (error, stackTrace) {
      _initialized = false;
      AppLogger.e('Daily notification init failed', error, stackTrace);
    }
  }

  /// Payload of the notification that cold-started the app, if any.
  Future<String?> launchPayload() async {
    try {
      final details = await _plugin.getNotificationAppLaunchDetails();
      if (details?.didNotificationLaunchApp ?? false) {
        return details?.notificationResponse?.payload;
      }
    } catch (error, stackTrace) {
      AppLogger.e('Reading launch details failed', error, stackTrace);
    }
    return null;
  }

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  /// Whether the OS lets the app schedule exact alarms. On Android 14+ this
  /// is denied by default; without it only inexact scheduling is possible.
  Future<bool> canScheduleExact() async {
    try {
      return await _android?.canScheduleExactNotifications() ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Opens the system "Alarms & reminders" screen for the app. Returns the
  /// resulting state.
  Future<bool> requestExactAlarmPermission() async {
    try {
      return await _android?.requestExactAlarmsPermission() ?? false;
    } catch (error, stackTrace) {
      AppLogger.e('Exact alarm permission request failed', error, stackTrace);
      return false;
    }
  }

  /// Replaces every scheduled daily notification (debug one excluded) with
  /// [entries]. Returns the ids that were actually scheduled — callers must
  /// only record those, never the ones that failed.
  Future<Set<String>> scheduleAll(List<DailyNotificationEntry> entries) async {
    await _cancelPending(keepDebug: true);
    final exact = await canScheduleExact();
    final scheduled = <String>{};
    for (final entry in entries) {
      if (await _schedule(entry, _notificationIdFor(entry.id), exact: exact)) {
        scheduled.add(entry.id);
      }
    }
    return scheduled;
  }

  Future<void> cancelAll() => _cancelPending(keepDebug: true);

  /// Debug-only test notification, kept apart from the real schedule: its
  /// own id, replaced/cancelled independently of [scheduleAll].
  Future<bool> scheduleDebug(DailyNotificationEntry entry) async =>
      _schedule(entry, _debugNotificationId, exact: await canScheduleExact());

  Future<void> cancelDebug() async {
    try {
      await _plugin.cancel(id: _debugNotificationId);
    } catch (error, stackTrace) {
      AppLogger.e('Cancel debug notification failed', error, stackTrace);
    }
  }

  /// Payload ids still waiting to fire. A scheduled notification that is no
  /// longer pending after its time has been delivered.
  Future<Set<String>> pendingIds() async {
    try {
      final pending = await _plugin.pendingNotificationRequests();
      return {
        for (final p in pending)
          if (p.payload != null) p.payload!,
      };
    } catch (error, stackTrace) {
      AppLogger.e('Reading pending notifications failed', error, stackTrace);
      return {};
    }
  }

  /// Exact (`alarmClock`: exempt from Doze throttling) when the OS permits
  /// it; otherwise inexact-while-idle, which still delivers but can be
  /// deferred by minutes in Doze. A permission failure falls back rather
  /// than dropping the notification.
  Future<bool> _schedule(
    DailyNotificationEntry entry,
    int notificationId, {
    required bool exact,
  }) async {
    Future<void> attempt(AndroidScheduleMode mode) => _plugin.zonedSchedule(
      id: notificationId,
      title: entry.title,
      body: entry.body,
      // An absolute instant, expressed in UTC so it never depends on the
      // device's timezone database or a later DST change.
      scheduledDate: tz.TZDateTime.fromMillisecondsSinceEpoch(
        tz.UTC,
        entry.triggerAt.millisecondsSinceEpoch,
      ),
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: 'A daily verse and hadith to read',
          importance: Importance.max,
          priority: Priority.max,
          playSound: true,
          enableVibration: true,
          icon: _smallIcon,
          // Public + reminder category + max priority: shown (not hidden)
          // on the lock screen and eligible for the heads-up / wake
          // treatment the device grants high-priority notifications.
          category: AndroidNotificationCategory.reminder,
          visibility: NotificationVisibility.public,
          ticker: entry.title,
          styleInformation: BigTextStyleInformation(entry.body),
        ),
      ),
      androidScheduleMode: mode,
      payload: entry.id,
    );

    try {
      try {
        await attempt(
          exact
              ? AndroidScheduleMode.alarmClock
              : AndroidScheduleMode.inexactAllowWhileIdle,
        );
      } on PlatformException catch (e) {
        if (e.code != 'exact_alarms_not_permitted') rethrow;
        await attempt(AndroidScheduleMode.inexactAllowWhileIdle);
      }
      return true;
    } catch (error, stackTrace) {
      AppLogger.e('Scheduling daily notification failed', error, stackTrace);
      return false;
    }
  }

  Future<void> _cancelPending({required bool keepDebug}) async {
    try {
      final pending = await _plugin.pendingNotificationRequests();
      for (final p in pending) {
        if (keepDebug && p.id == _debugNotificationId) continue;
        await _plugin.cancel(id: p.id);
      }
    } catch (error, stackTrace) {
      AppLogger.e('Cancelling daily notifications failed', error, stackTrace);
    }
  }

  /// 'yyyy-MM-dd' → 20261001. Stable per day, so re-scheduling a day
  /// replaces its notification instead of duplicating it.
  static int _notificationIdFor(String id) =>
      int.tryParse(id.replaceAll('-', '')) ?? id.hashCode & 0x7fffffff;
}
