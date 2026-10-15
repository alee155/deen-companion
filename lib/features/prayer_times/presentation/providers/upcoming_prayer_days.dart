import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/prayer_times.dart';
import 'prayer_times_loader.dart';

typedef UpcomingPrayerDays = ({List<PrayerTimes> days, String? error});

/// Per-day timings covering [windowDays] from [now], for features that arm
/// native alarms ahead of time (reminders, Do Not Disturb, daily content).
///
/// The server hands out up to 31 days at once and the app keeps them, so this
/// reads the cached days and only asks the server when the cache does not
/// reach [windowDays] ahead. A failed refresh still returns whatever the cache
/// holds; [error] is set only when there is nothing usable at all.
Future<UpcomingPrayerDays> loadUpcomingPrayerDays(
  Ref ref, {
  required DateTime now,
  required int windowDays,
}) async {
  final repository = ref.read(prayerTimesRepositoryProvider);
  final today = DateTime(now.year, now.month, now.day);
  final needUntil = today.add(Duration(days: windowDays));

  List<PrayerTimes> fromCache() => [
    for (final d in repository.getCachedBundle()?.days ?? const [])
      if (!_dateOnly(d.times.fajr).isBefore(today)) d.times,
  ];

  var days = fromCache();
  final covered =
      days.isNotEmpty && !_dateOnly(days.last.fajr).isBefore(needUntil);
  if (covered) return (days: days, error: null);

  final result = await ref.read(prayerTimesLoaderProvider).refresh();
  final failure = result.when(success: (_) => null, failure: (f) => f);
  days = fromCache();
  if (failure != null && days.isEmpty) {
    return (days: days, error: failure.message);
  }
  return (days: days, error: null);
}

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
