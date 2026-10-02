import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/storage/local_storage_service.dart';
import '../../../../core/utils/logger.dart';
import '../../../prayer_times/domain/entities/prayer_times.dart';
import '../../../prayer_times/presentation/providers/upcoming_prayer_days.dart';
import '../../data/prayer_alarm_channel.dart';
import '../../domain/prayer_reminder_prefs.dart';

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
    final now = DateTime.now();

    final loaded = await loadUpcomingPrayerDays(
      ref,
      now: now,
      windowDays: _windowDays,
    );
    if (loaded.error != null) return ReminderSyncFailed(loaded.error!);
    final days = loaded.days;

    final prefs = ref.read(prayerReminderPrefsProvider);
    if (!prefs.values.any((p) => p.enabled)) {
      // Every prayer switched off: nothing to arm, and anything armed
      // earlier must go.
      await channel.cancelAll();
      return const ReminderSyncScheduled(0, 0);
    }

    final entries = _buildEntries(days, now, prefs);
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

  List<PrayerAlarmEntry> _buildEntries(
    List<PrayerTimes> days,
    DateTime now,
    PrayerPrefsMap prefs,
  ) {
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
        final pref = prefs[entry.key] ?? PrayerReminderPrefs.defaults;
        if (!pref.enabled) continue;
        // Anything already past is dropped — arming it would fire the alarm
        // immediately on some OEM builds.
        if (!entry.value.isAfter(now) || entry.value.isAfter(horizon)) continue;
        entries.add(
          PrayerAlarmEntry(
            prayerName: entry.key.name,
            triggerAt: entry.value,
            label: '${_prayerLabels[entry.key]} — time to pray',
            snoozeEnabled: pref.snoozeEnabled,
            snoozeMinutes: pref.snoozeMinutes,
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

// ── Per-prayer preferences ───────────────────────────────────────────────

/// What the Reminders screen shows about the last attempt to apply settings
/// to the native scheduler. Only ever [ReminderApplied] after the native
/// side confirmed — so the UI never claims settings that didn't take.
sealed class ReminderApplyState {
  const ReminderApplyState();
}

class ReminderIdle extends ReminderApplyState {
  const ReminderIdle();
}

class ReminderApplying extends ReminderApplyState {
  const ReminderApplying();
}

class ReminderApplied extends ReminderApplyState {
  final String message;
  const ReminderApplied(this.message);
}

class ReminderApplyFailed extends ReminderApplyState {
  final String message;
  const ReminderApplyFailed(this.message);
}

class ReminderApplyNotifier extends Notifier<ReminderApplyState> {
  @override
  ReminderApplyState build() => const ReminderIdle();

  void set(ReminderApplyState value) => state = value;
}

final reminderApplyProvider =
    NotifierProvider<ReminderApplyNotifier, ReminderApplyState>(
      ReminderApplyNotifier.new,
    );

/// Human summary of a successful sync, shared by the toggle and prefs paths.
String describeSync(ReminderSyncResult result) => switch (result) {
  ReminderSyncScheduled(:final alarmCount, :final dayCount) =>
    alarmCount == 0
        ? 'No prayers selected — no alarms are armed.'
        : 'Saved · $alarmCount alarms armed for the next $dayCount days.',
  ReminderSyncFailed(:final message) => message,
  ReminderSyncDisabled() => 'Reminders are off.',
};

class PrayerReminderPrefsNotifier extends Notifier<PrayerPrefsMap> {
  @override
  PrayerPrefsMap build() => decodePrayerPrefs(
    ref
        .read(localStorageServiceProvider)
        .get<String>(
          AppConstants.settingsBoxName,
          AppConstants.prayerReminderPrefsKey,
        ),
  );

  Future<void> _persist(PrayerPrefsMap value) => ref
      .read(localStorageServiceProvider)
      .put(
        AppConstants.settingsBoxName,
        AppConstants.prayerReminderPrefsKey,
        encodePrayerPrefs(value),
      );

  /// Applies [next] and pushes it to the native scheduler. If the master
  /// switch is on and the native side doesn't confirm, the change is rolled
  /// back, so what's on screen is what's actually armed.
  Future<void> _apply(PrayerPrefsMap next) async {
    final previous = state;
    final notifier = ref.read(reminderApplyProvider.notifier);
    state = next;
    await _persist(next);

    if (!ref.read(remindersEnabledProvider)) {
      notifier.set(const ReminderIdle());
      return;
    }

    notifier.set(const ReminderApplying());
    final result = await ref.read(prayerReminderServiceProvider).sync();
    if (result is ReminderSyncFailed) {
      state = previous;
      await _persist(previous);
      notifier.set(ReminderApplyFailed(result.message));
    } else {
      notifier.set(ReminderApplied(describeSync(result)));
    }
  }

  Future<void> update(PrayerName prayer, PrayerReminderPrefs prefs) =>
      _apply({...state, prayer: prefs});

  /// "All on" / "All off".
  Future<void> setAllEnabled(bool enabled) => _apply({
    for (final e in state.entries) e.key: e.value.copyWith(enabled: enabled),
  });
}

final prayerReminderPrefsProvider =
    NotifierProvider<PrayerReminderPrefsNotifier, PrayerPrefsMap>(
      PrayerReminderPrefsNotifier.new,
    );
