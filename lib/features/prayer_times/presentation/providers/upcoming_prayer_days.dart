import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/utils/flow_log.dart';
import '../../domain/entities/prayer_times.dart';
import '../../domain/entities/prayer_times_bundle.dart';
import 'prayer_calculation_settings_provider.dart';
import 'prayer_times_loader.dart';

typedef UpcomingPrayerDays = ({List<PrayerTimes> days, String? error});

/// Per-day timings covering [windowDays] from [now], for features that arm
/// native alarms ahead of time (reminders, Do Not Disturb, daily content).
///
/// The server hands out up to 31 days at once and the app keeps them, so this
/// reads the cached days and only asks the server when it must:
/// - the cache does not reach [windowDays] ahead, or
/// - the user changed method/school and the server has not confirmed it yet
///   (the cache still holds the old times).
///
/// Days come from the refresh itself when there was one, so unverified
/// fallback times (never cached) can still be armed. A failed refresh still
/// returns whatever the cache holds; [error] is set only when there is nothing
/// usable at all.
Future<UpcomingPrayerDays> loadUpcomingPrayerDays(
  Ref ref, {
  required DateTime now,
  required int windowDays,
}) async {
  const tag = 'UPCOMING DAYS';
  final repository = ref.read(prayerTimesRepositoryProvider);
  final today = DateTime(now.year, now.month, now.day);
  final needUntil = today.add(Duration(days: windowDays));

  List<PrayerTimes> upcoming(Iterable<PrayerTimesDay> all) => [
    for (final d in all)
      if (!_dateOnly(d.times.fajr).isBefore(today)) d.times,
  ];

  var days = upcoming(repository.getCachedBundle()?.days ?? const []);
  final covered =
      days.isNotEmpty && !_dateOnly(days.last.fajr).isBefore(needUntil);
  final pendingChange = ref
      .read(prayerCalculationSettingsProvider.notifier)
      .choice
      .changedByUser;

  FlowLog.log(
    tag,
    'ALARM FEATURES NEED $windowDays DAYS AHEAD: ${days.length} cached -> '
    '${pendingChange
        ? 'a method/school change is not confirmed by the server yet, refreshing first'
        : covered
        ? 'cache is enough, no request'
        : 'not enough, refreshing from the server'}',
  );
  if (covered && !pendingChange) return (days: days, error: null);

  final result = await ref.read(prayerTimesLoaderProvider).refresh();
  return result.when(
    success: (bundle) {
      days = upcoming(bundle.days);
      FlowLog.log(
        tag,
        'USING ${days.length} DAYS FROM THE SERVER'
        '${bundle.isUnverified ? ' (UNVERIFIED Aladhan fallback)' : ''}',
      );
      return (days: days, error: null);
    },
    failure: (failure) {
      // Keep what is cached; say so only when there is nothing at all.
      FlowLog.log(
        tag,
        days.isEmpty
            ? 'REFRESH FAILED AND NOTHING CACHED -> alarms cannot be built'
            : 'REFRESH FAILED -> USING THE ${days.length} CACHED DAYS',
      );
      if (days.isNotEmpty) return (days: days, error: null);
      return (days: days, error: _explain(failure));
    },
  );
}

/// The message for a failure with no cache to fall back on. A location
/// problem also points at the city picker, which works without a permission.
String _explain(Failure failure) => failure is LocationFailure
    ? '${failure.message} You can also choose a city in Prayer settings.'
    : failure.message;

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
