import 'entities/prayer_times.dart';
import 'entities/prayer_times_bundle.dart';

/// The day to show as "today": the last day whose Fajr has started, so the
/// hours between Isha and midnight still belong to today's list. Falls back
/// to the first day when none has started yet.
PrayerTimes? todayOf(List<PrayerTimesDay> days, DateTime now) {
  if (days.isEmpty) return null;
  PrayerTimesDay chosen = days.first;
  for (final d in days) {
    if (d.times.fajr.isAfter(now)) break;
    chosen = d;
  }
  return chosen.times;
}
