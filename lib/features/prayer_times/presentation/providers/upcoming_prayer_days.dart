import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/prayer_times.dart';
import 'prayer_calculation_settings_provider.dart';
import 'prayer_times_provider.dart';

typedef UpcomingPrayerDays = ({List<PrayerTimes> days, String? error});

/// Per-day timings covering [windowDays] from [now], for features that arm
/// native alarms ahead of time (reminders, Do Not Disturb).
///
/// The month calendar gives a real per-day set of timings; two calls cover a
/// window that straddles a month boundary. If the fetch fails and nothing was
/// loaded, falls back to today's cached timings — one day beats none. [error]
/// is set only when there is nothing usable at all.
Future<UpcomingPrayerDays> loadUpcomingPrayerDays(
  Ref ref, {
  required DateTime now,
  required int windowDays,
}) async {
  final settings = ref.read(prayerCalculationSettingsProvider);
  final repository = ref.read(prayerTimesRepositoryProvider);
  final end = now.add(Duration(days: windowDays));

  final days = <PrayerTimes>[];
  final months = <({int year, int month})>{
    (year: now.year, month: now.month),
    (year: end.year, month: end.month),
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
      final cached = repository.getCachedPrayerTimesForLastKnownLocation();
      if (cached == null) return (days: days, error: failure.message);
      days.add(cached);
    }
  }
  return (days: days, error: null);
}
