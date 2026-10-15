import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/storage/local_storage_service.dart';
import '../../../../core/utils/flow_log.dart';
import '../../../../core/utils/logger.dart';
import '../../../prayer_times/domain/entities/prayer_times.dart';
import '../../../prayer_times/presentation/providers/prayer_times_loader.dart'
    show prayerTimesUpdatedProvider;
import '../../../prayer_times/presentation/providers/upcoming_prayer_days.dart';
import '../../data/prayer_dnd_channel.dart';
import '../../domain/dnd_settings.dart';
import '../../domain/dnd_window_planner.dart';

/// Persisted DND preferences. Every setter writes straight to storage; call
/// [PrayerDndService.syncIfEnabled] afterwards to re-arm with the new values.
class DndSettingsNotifier extends Notifier<DndSettings> {
  static const _box = AppConstants.settingsBoxName;

  LocalStorageService get _storage => ref.read(localStorageServiceProvider);

  @override
  DndSettings build() {
    final storage = ref.read(localStorageServiceProvider);
    final modeName = storage.get<String>(_box, AppConstants.dndDurationModeKey);
    final mode = DndDurationMode.values.firstWhere(
      (m) => m.name == modeName,
      orElse: () => DndDurationMode.preset,
    );

    return DndSettings(
      enabled: storage.get<bool>(_box, AppConstants.dndEnabledKey) ?? false,
      mode: mode,
      durations: _readDurations(storage) ?? const {},
    );
  }

  /// Reads the per-prayer map, migrating the older single-duration settings
  /// (one preset/custom value for a set of prayers) the first time.
  Map<PrayerName, int>? _readDurations(LocalStorageService storage) {
    final raw = storage.get<Map>(_box, AppConstants.dndDurationsKey);
    if (raw != null) {
      final result = <PrayerName, int>{};
      for (final prayer in PrayerName.values) {
        final value = raw[prayer.name];
        if (value is int && value > 0) result[prayer] = value;
      }
      return result;
    }

    final legacyMode = storage.get<String>(
      _box,
      AppConstants.dndDurationModeKey,
    );
    final legacyPrayers = storage.get<List>(_box, AppConstants.dndPrayersKey);
    final int? minutes = switch (legacyMode) {
      'preset' =>
        storage.get<int>(_box, AppConstants.dndPresetMinutesKey) ?? 20,
      'custom' => storage.get<int>(_box, AppConstants.dndCustomMinutesKey),
      _ => null, // "until next prayer" no longer exists
    };
    if (minutes == null) return null;
    final migrated = <PrayerName, int>{
      for (final p in PrayerName.values)
        if (legacyPrayers == null || legacyPrayers.contains(p.name))
          p: minutes.clamp(
            DndSettings.minCustomMinutes,
            DndSettings.maxCustomMinutes,
          ),
    };
    // Persist so the migration runs once.
    _persistDurations(migrated);
    return migrated;
  }

  Future<void> _persistDurations(Map<PrayerName, int> durations) =>
      _storage.put(_box, AppConstants.dndDurationsKey, {
        for (final e in durations.entries) e.key.name: e.value,
      });

  Future<void> setEnabled(bool enabled) async {
    state = state.copyWith(enabled: enabled);
    await _storage.put(_box, AppConstants.dndEnabledKey, enabled);
  }

  Future<void> setMode(DndDurationMode mode) async {
    state = state.copyWith(mode: mode);
    await _storage.put(_box, AppConstants.dndDurationModeKey, mode.name);
  }

  Future<void> _write(Map<PrayerName, int> next) async {
    state = state.copyWith(durations: next);
    await _persistDurations(next);
  }

  int _clamp(int minutes) =>
      minutes.clamp(DndSettings.minCustomMinutes, DndSettings.maxCustomMinutes);

  /// Sets (or replaces) the duration for one prayer.
  Future<void> setDuration(PrayerName prayer, int minutes) =>
      _write({...state.durations, prayer: _clamp(minutes)});

  /// Removes a prayer's configuration; it will no longer trigger DND.
  Future<void> clearDuration(PrayerName prayer) =>
      _write({...state.durations}..remove(prayer));

  /// Same duration for every prayer.
  Future<void> setAllDurations(int minutes) =>
      _write({for (final p in PrayerName.values) p: _clamp(minutes)});

  Future<void> clearAllDurations() => _write(const {});
}

final dndSettingsProvider = NotifierProvider<DndSettingsNotifier, DndSettings>(
  DndSettingsNotifier.new,
);

/// The next occurrence of each prayer, from the same cached days the rest of
/// the app uses. Drives the times shown next to each prayer, so each value is
/// the clock reading at the prayer location (what the user sees on the prayer
/// screens), not the phone's zone.
final dndUpcomingTimesProvider =
    FutureProvider.autoDispose<Map<PrayerName, DateTime>>((ref) async {
      final now = DateTime.now();
      final loaded = await loadUpcomingPrayerDays(ref, now: now, windowDays: 2);
      // The instant decides which occurrence is next; the clock is for display.
      final next = <PrayerName, ({DateTime instant, DateTime clock})>{};
      for (final day in loaded.days) {
        final times = {
          PrayerName.fajr: day.fajr,
          PrayerName.dhuhr: day.dhuhr,
          PrayerName.asr: day.asr,
          PrayerName.maghrib: day.maghrib,
          PrayerName.isha: day.isha,
        };
        for (final e in times.entries) {
          if (!e.value.isAfter(now)) continue;
          final current = next[e.key];
          if (current == null || e.value.isBefore(current.instant)) {
            next[e.key] = (instant: e.value, clock: day.wallClock(e.value));
          }
        }
      }
      return {for (final e in next.entries) e.key: e.value.clock};
    });

sealed class DndSyncResult {
  const DndSyncResult();
}

class DndSyncScheduled extends DndSyncResult {
  final int windowCount;
  const DndSyncScheduled(this.windowCount);
}

/// Feature is on but no prayer has a duration yet — not an error.
class DndSyncNothingConfigured extends DndSyncResult {
  const DndSyncNothingConfigured();
}

class DndSyncFailed extends DndSyncResult {
  final String message;
  const DndSyncFailed(this.message);
}

class DndSyncDisabled extends DndSyncResult {
  const DndSyncDisabled();
}

/// Loads prayer timings, plans windows and hands them to the native side,
/// which owns the alarms (so they fire with the app closed and are re-armed
/// after reboot without Dart). Dart re-pushes a rolling window on app start
/// and whenever settings change.
class PrayerDndService {
  final Ref ref;
  PrayerDndService(this.ref);

  static const _tag = 'DND';

  bool _resyncing = false;
  bool _resyncAgain = false;

  /// The prayer times changed: re-plan the windows so they match. Overlapping
  /// triggers collapse into one extra run; nothing happens when DND is off.
  Future<void> onTimesChanged() async {
    final enabled = ref.read(dndSettingsProvider).enabled;
    FlowLog.log(
      _tag,
      'PRAYER TIMES CHANGED -> ${enabled ? 're-planning the DND windows' : 'DND is off, nothing to re-plan'}',
    );
    if (_resyncing) {
      _resyncAgain = true;
      return;
    }
    _resyncing = true;
    try {
      do {
        _resyncAgain = false;
        await syncIfEnabled();
      } while (_resyncAgain);
    } catch (error, stackTrace) {
      AppLogger.e('Prayer DND re-plan failed', error, stackTrace);
    } finally {
      _resyncing = false;
    }
  }

  Future<DndSyncResult> syncIfEnabled() async {
    if (!ref.read(dndSettingsProvider).enabled) {
      FlowLog.log(_tag, 'SYNC SKIPPED: Do Not Disturb is switched off');
      return const DndSyncDisabled();
    }
    return sync();
  }

  Future<DndSyncResult> sync() async {
    final settings = ref.read(dndSettingsProvider);
    final channel = ref.read(prayerDndChannelProvider);

    FlowLog.log(
      _tag,
      'SYNC STARTED: ${settings.configuredCount} prayer(s) have a duration',
    );
    if (settings.configuredCount == 0) {
      FlowLog.log(_tag, 'NO PRAYER HAS A DURATION -> CANCELLING ALL WINDOWS');
      await channel.cancelAll();
      return const DndSyncNothingConfigured();
    }

    final now = DateTime.now();
    final loaded = await loadUpcomingPrayerDays(
      ref,
      now: now,
      windowDays: DndWindowPlanner.horizonDays,
    );
    if (loaded.error != null) {
      FlowLog.error(_tag, 'SYNC FAILED: no prayer times', loaded.error);
      return DndSyncFailed(loaded.error!);
    }

    final windows = DndWindowPlanner.build(loaded.days, settings, now);
    FlowLog.data(_tag, 'PLANNED WINDOWS', {
      'count': windows.length,
      if (windows.isNotEmpty)
        'first':
            '${windows.first.prayerName} ${windows.first.start.toIso8601String()} -> ${windows.first.end.toIso8601String()}',
      if (windows.isNotEmpty)
        'last':
            '${windows.last.prayerName} ${windows.last.start.toIso8601String()}',
    });
    final armed = await channel.pushSchedule(windows);
    if (armed == null) {
      FlowLog.error(_tag, 'NATIVE SCHEDULER UNAVAILABLE on this device');
      return const DndSyncFailed(
        'Prayer Do Not Disturb is not available on this device.',
      );
    }
    FlowLog.log(_tag, 'NATIVE SCHEDULER ARMED $armed WINDOWS');
    AppLogger.i('Prayer DND: armed $armed windows');
    return DndSyncScheduled(armed);
  }

  Future<void> cancelAll() {
    FlowLog.log(_tag, 'CANCELLING ALL DND WINDOWS');
    return ref.read(prayerDndChannelProvider).cancelAll();
  }
}

final prayerDndServiceProvider = Provider<PrayerDndService>((ref) {
  final service = PrayerDndService(ref);
  // The times the windows were planned from changed: re-plan.
  ref.listen(prayerTimesUpdatedProvider, (_, _) => service.onTimesChanged());
  return service;
});
