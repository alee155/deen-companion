import '../../prayer_times/domain/entities/prayer_times.dart';
import 'dnd_settings.dart';
import 'dnd_window.dart';

/// Turns per-day prayer timings + the user's per-prayer durations into the
/// DND windows to arm. Pure, so it is unit-tested without any platform.
class DndWindowPlanner {
  const DndWindowPlanner._();

  /// How far ahead windows are armed. 28 days always touches at most two
  /// calendar months, which is what the month-calendar loader fetches.
  static const horizonDays = 28;

  static List<DndWindow> build(
    List<PrayerTimes> days,
    DndSettings settings,
    DateTime now, {
    int windowDays = horizonDays,
  }) {
    final horizon = now.add(Duration(days: windowDays));
    final windows = <DndWindow>[];
    final seen = <String>{};

    for (final day in days) {
      final times = <PrayerName, DateTime>{
        PrayerName.fajr: day.fajr,
        PrayerName.dhuhr: day.dhuhr,
        PrayerName.asr: day.asr,
        PrayerName.maghrib: day.maghrib,
        PrayerName.isha: day.isha,
      };
      for (final entry in times.entries) {
        final minutes = settings.minutesFor(entry.key);
        if (minutes == null || minutes <= 0) continue;
        final start = entry.value;
        if (!start.isAfter(now) || start.isAfter(horizon)) continue;
        // Overlapping month lists can repeat a day.
        if (!seen.add('${entry.key.name}@${start.millisecondsSinceEpoch}')) {
          continue;
        }
        windows.add(
          DndWindow(
            prayerName: entry.key.name,
            start: start,
            end: start.add(Duration(minutes: minutes)),
          ),
        );
      }
    }
    windows.sort((a, b) => a.start.compareTo(b.start));
    return windows;
  }
}
