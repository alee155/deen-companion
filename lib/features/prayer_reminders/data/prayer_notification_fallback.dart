import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../core/utils/logger.dart';
import '../../daily_content/data/daily_notification_scheduler.dart';
import '../../daily_content/presentation/providers/daily_content_providers.dart';
import 'prayer_alarm_channel.dart';

/// Prayer reminders as ordinary scheduled notifications, for iOS versions
/// without AlarmKit (before iOS 26) or where the alarm permission was
/// declined. They carry the adhan sound and are marked time sensitive, but
/// unlike an alarm they stay silent when the phone is on silent.
///
/// Shares the one `flutter_local_notifications` plugin with the daily Ayat &
/// Hadith notification, in a separate id range so neither cancels the other.
class PrayerNotificationFallback {
  final DailyNotificationScheduler _scheduler;
  PrayerNotificationFallback(this._scheduler);

  /// First id of this feature's range (see
  /// [DailyNotificationScheduler.foreignIdBase]); the id is the trigger time
  /// in whole minutes since the epoch, offset into the range.
  static const _idBase = DailyNotificationScheduler.foreignIdBase;

  /// iOS keeps at most 64 pending notifications per app. Daily content uses
  /// up to a week of them, so reminders stop well short of the limit.
  static const _maxPending = 50;

  static const _sound = 'azan_ringtone.caf';

  FlutterLocalNotificationsPlugin get _plugin => _scheduler.plugin;

  /// Replaces every armed prayer notification with [entries]; returns how
  /// many were armed, or null if the plugin could not be used.
  Future<int?> pushSchedule(List<PrayerAlarmEntry> entries) async {
    try {
      await _scheduler.whenReady();
      await cancelAll();
      var armed = 0;
      for (final entry in entries.take(_maxPending)) {
        await _plugin.zonedSchedule(
          id: _idFor(entry.triggerAt),
          title: entry.label,
          body: 'It’s time to pray.',
          scheduledDate: tz.TZDateTime.fromMillisecondsSinceEpoch(
            tz.UTC,
            entry.triggerAt.millisecondsSinceEpoch,
          ),
          notificationDetails: const NotificationDetails(
            iOS: DarwinNotificationDetails(
              presentAlert: true,
              presentBanner: true,
              presentList: true,
              presentSound: true,
              sound: _sound,
              interruptionLevel: InterruptionLevel.timeSensitive,
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload:
              '${DailyNotificationScheduler.foreignPayloadPrefix}'
              '${entry.prayerName}',
        );
        armed++;
      }
      return armed;
    } on PlatformException catch (error, stackTrace) {
      AppLogger.e('Prayer notification fallback failed', error, stackTrace);
      return null;
    } catch (error, stackTrace) {
      AppLogger.e('Prayer notification fallback failed', error, stackTrace);
      return null;
    }
  }

  Future<void> cancelAll() async {
    try {
      await _scheduler.whenReady();
      final pending = await _plugin.pendingNotificationRequests();
      for (final p in pending) {
        if (p.id >= _idBase) await _plugin.cancel(id: p.id);
      }
    } catch (error, stackTrace) {
      AppLogger.e('Cancelling prayer notifications failed', error, stackTrace);
    }
  }

  static int _idFor(DateTime at) =>
      _idBase + (at.millisecondsSinceEpoch ~/ 60000);
}

final prayerNotificationFallbackProvider = Provider<PrayerNotificationFallback>(
  (ref) =>
      PrayerNotificationFallback(ref.watch(dailyNotificationSchedulerProvider)),
);
