import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/storage/local_storage_service.dart';
import '../../../../core/utils/logger.dart';
import '../../../prayer_times/domain/entities/prayer_times.dart';
import '../../../prayer_times/presentation/providers/prayer_calculation_settings_provider.dart';
import '../../../prayer_times/presentation/providers/prayer_times_provider.dart';
import '../../data/prayer_alarm_channel.dart';

const _prayerLabels = {
  PrayerName.fajr: 'Fajr',
  PrayerName.dhuhr: 'Dhuhr',
  PrayerName.asr: 'Asr',
  PrayerName.maghrib: 'Maghrib',
  PrayerName.isha: 'Isha',
};

/// Master on/off switch for prayer reminders, persisted so it survives a
/// restart (the native schedule survives independently, in SharedPreferences).
class RemindersEnabledNotifier extends Notifier<bool> {
  @override
  bool build() {
    return ref
            .read(localStorageServiceProvider)
            .get<bool>(
              AppConstants.settingsBoxName,
              AppConstants.remindersEnabledKey,
            ) ??
        false;
  }

  Future<void> set(bool enabled) async {
    state = enabled;
    await ref
        .read(localStorageServiceProvider)
        .put(
          AppConstants.settingsBoxName,
          AppConstants.remindersEnabledKey,
          enabled,
        );
  }
}

final remindersEnabledProvider =
    NotifierProvider<RemindersEnabledNotifier, bool>(
      RemindersEnabledNotifier.new,
    );

/// Outcome of pushing a schedule, so the UI can say something specific
/// instead of just flipping a switch and hoping.
sealed class ReminderSyncResult {
  const ReminderSyncResult();
}

class ReminderSyncScheduled extends ReminderSyncResult {
  final int alarmCount;
  final int dayCount;
  const ReminderSyncScheduled(this.alarmCount, this.dayCount);
}

class ReminderSyncFailed extends ReminderSyncResult {
  final String message;
  const ReminderSyncFailed(this.message);
}

class ReminderSyncDisabled extends ReminderSyncResult {
  const ReminderSyncDisabled();
}

/// Builds the rolling alarm window and hands it to the native scheduler.
///
/// The native side re-arms whatever is still in the future (on boot, and via
/// a 12-hour backstop worker) but never fetches prayer times itself — so Dart
/// pushes a multi-day window and refreshes it whenever the app opens, the
/// toggle changes, or the calculation settings change.
class PrayerReminderService {
  final Ref ref;
  const PrayerReminderService(this.ref);

  /// How far ahead to arm alarms. Long enough that a user who doesn't open
  /// the app for a few days still gets reminded, short enough that timings
  /// stay accurate as the location/season drifts.
  static const _windowDays = 7;

  Future<ReminderSyncResult> syncIfEnabled() async {
    if (!ref.read(remindersEnabledProvider)) {
      return const ReminderSyncDisabled();
    }
    return sync();
  }

  Future<ReminderSyncResult> sync() async {
    final channel = ref.read(prayerAlarmChannelProvider);
    final settings = ref.read(prayerCalculationSettingsProvider);
    final repository = ref.read(prayerTimesRepositoryProvider);
    final now = DateTime.now();

    final days = <PrayerTimes>[];

    // The month calendar gives a real per-day set of timings; two calls cover
    // a window that straddles a month boundary.
    final months = <({int year, int month})>{
      (year: now.year, month: now.month),
      (
        year: now.add(const Duration(days: _windowDays)).year,
        month: now.add(const Duration(days: _windowDays)).month,
      ),
    };

    for (final month in months) {
      final result = await repository.fetchMonthCalendar(
        year: month.year,
        month: month.month,
        method: settings.method.id,
        school: settings.school.id,
      );
      final failure = result.when(
        success: (data) {
          days.addAll(data);
          return null;
        },
        failure: (f) => f,
      );
      if (failure != null && days.isEmpty) {
        // Fall back to today's cached timings rather than giving up entirely:
        // one day of reminders beats none, and the backstop worker will keep
        // them armed until the app can fetch the full window.
        final cached = repository.getCachedPrayerTimesForLastKnownLocation();
        if (cached == null) return ReminderSyncFailed(failure.message);
        days.add(cached);
      }
    }

    final entries = _buildEntries(days, now);
    if (entries.isEmpty) {
      return const ReminderSyncFailed(
        "Couldn't work out any upcoming prayer times to remind you about.",
      );
    }

    final armed = await channel.pushSchedule(entries);
    if (armed == null) {
      return const ReminderSyncFailed(
        'Prayer reminders are not available on this device.',
      );
    }

    final dayCount = entries
        .map(
          (e) => DateTime(e.triggerAt.year, e.triggerAt.month, e.triggerAt.day),
        )
        .toSet()
        .length;
    AppLogger.i('Prayer reminders: armed $armed alarms across $dayCount days');
    return ReminderSyncScheduled(armed, dayCount);
  }

  Future<void> cancelAll() async {
    await ref.read(prayerAlarmChannelProvider).cancelAll();
  }

  List<PrayerAlarmEntry> _buildEntries(List<PrayerTimes> days, DateTime now) {
    final horizon = now.add(const Duration(days: _windowDays));
    final entries = <PrayerAlarmEntry>[];

    for (final day in days) {
      final timings = {
        PrayerName.fajr: day.fajr,
        PrayerName.dhuhr: day.dhuhr,
        PrayerName.asr: day.asr,
        PrayerName.maghrib: day.maghrib,
        PrayerName.isha: day.isha,
      };

      for (final entry in timings.entries) {
        // Anything already past is dropped — arming it would fire the alarm
        // immediately on some OEM builds.
        if (!entry.value.isAfter(now) || entry.value.isAfter(horizon)) continue;
        entries.add(
          PrayerAlarmEntry(
            prayerName: entry.key.name,
            triggerAt: entry.value,
            label: '${_prayerLabels[entry.key]} — time to pray',
          ),
        );
      }
    }

    entries.sort((a, b) => a.triggerAt.compareTo(b.triggerAt));
    return entries;
  }
}

final prayerReminderServiceProvider = Provider<PrayerReminderService>((ref) {
  return PrayerReminderService(ref);
});
