import '../../prayer_times/domain/entities/prayer_times.dart';
import 'current_prayer.dart';

/// How one of the five prayers stands for someone today.
enum DayPrayer {
  /// Logged.
  logged,

  /// Its time has closed and nothing was logged.
  missed,

  /// Still to come, or open right now and not logged yet.
  pending,
}

/// Fajr to Isha as logged / missed / pending, from what was logged ([done])
/// and the server's answer about the open prayer ([window]). [now] is the
/// server's clock.
///
/// A prayer counts as missed only when it is certain its time has closed: it
/// comes before the open prayer, or before the next one. Between Isha and
/// Fajr, and without the server's answer, nothing is called missed, since the
/// answer cannot tell which day the next Fajr belongs to.
List<DayPrayer> dayPrayers({
  required Set<PrayerName> done,
  required CurrentPrayerState? window,
  required DateTime now,
}) {
  const order = PrayerName.values;
  final open = window?.current;
  final next = window?.next;

  int? closedBefore;
  if (open != null) {
    final i = order.indexOf(open.prayer);
    // A window that has just ended (the answer not yet refreshed) is closed
    // too.
    closedBefore = now.isBefore(open.endsAt) ? i : i + 1;
  } else if (next != null && next.prayer != PrayerName.fajr) {
    closedBefore = order.indexOf(next.prayer);
  }

  return [
    for (final (i, p) in order.indexed)
      if (done.contains(p))
        DayPrayer.logged
      else if (closedBefore != null && i < closedBefore)
        DayPrayer.missed
      else
        DayPrayer.pending,
  ];
}
