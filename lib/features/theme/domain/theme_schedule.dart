import '../../prayer_times/domain/entities/prayer_times.dart';

/// The six looks of the automatic theme, one per stretch of the day.
enum ThemePeriod { fajr, sunrise, dhuhr, asr, maghrib, isha }

/// When each [ThemePeriod] begins, as a sorted list of instants.
///
/// Pure data and arithmetic — no Flutter, no clock, no providers — so every
/// edge case is a plain unit test. Before the first slot (after midnight,
/// ahead of Fajr) it is still night, i.e. [ThemePeriod.isha].
class ThemeSchedule {
  final List<({DateTime start, ThemePeriod period})> slots;

  const ThemeSchedule(this.slots);

  /// How long the warm "sunrise" look lasts before the bright day look.
  static const sunriseWindow = Duration(minutes: 90);

  /// How long the sunset look lasts after Maghrib before night falls, unless
  /// Isha begins sooner.
  static const maghribWindow = Duration(minutes: 45);

  /// Built from the server's prayer times. Returns null when the times can't
  /// be trusted for [now]: out of order, or belonging to another day. The
  /// caller then uses [ThemeSchedule.approximate].
  ///
  /// Dhuhr's look starts when the sunrise window ends (or at Dhuhr if that is
  /// sooner), so the bright day look covers the whole stretch up to Asr. A
  /// missing sunrise (old cached times) folds Sunrise into Fajr.
  static ThemeSchedule? fromPrayerTimes(PrayerTimes t, DateTime now) {
    final nextFajr = t.nextFajr;
    final dayEnd = nextFajr ?? t.fajr.add(const Duration(days: 1));
    // Stale or from another day: don't theme the wrong part of the day.
    if (!now.isBefore(dayEnd) ||
        now.isBefore(t.fajr.subtract(const Duration(hours: 12)))) {
      return null;
    }

    final sunrise = t.sunrise;
    final slots = <({DateTime start, ThemePeriod period})>[
      (start: t.fajr, period: ThemePeriod.fajr),
      if (sunrise != null) (start: sunrise, period: ThemePeriod.sunrise),
      (
        start: sunrise == null
            ? t.dhuhr
            : _earlier(sunrise.add(sunriseWindow), t.dhuhr),
        period: ThemePeriod.dhuhr,
      ),
      (start: t.asr, period: ThemePeriod.asr),
      (start: t.maghrib, period: ThemePeriod.maghrib),
      (
        start: _earlier(t.maghrib.add(maghribWindow), t.isha),
        period: ThemePeriod.isha,
      ),
      if (nextFajr != null) (start: nextFajr, period: ThemePeriod.fajr),
    ];

    for (var i = 1; i < slots.length; i++) {
      if (!slots[i].start.isAfter(slots[i - 1].start)) return null;
    }
    return ThemeSchedule(slots);
  }

  /// A rough day by the device clock, for when prayer times aren't available
  /// (first launch offline, no location, bad data). Plausible, not exact.
  factory ThemeSchedule.approximate(DateTime now) {
    DateTime at(int day, int h, [int m = 0]) =>
        DateTime(now.year, now.month, now.day + day, h, m);
    return ThemeSchedule([
      (start: at(0, 5), period: ThemePeriod.fajr),
      (start: at(0, 6, 30), period: ThemePeriod.sunrise),
      (start: at(0, 8), period: ThemePeriod.dhuhr),
      (start: at(0, 15, 30), period: ThemePeriod.asr),
      (start: at(0, 18), period: ThemePeriod.maghrib),
      (start: at(0, 19), period: ThemePeriod.isha),
      (start: at(1, 5), period: ThemePeriod.fajr),
    ]);
  }

  /// Prefers real times; falls back to [approximate].
  factory ThemeSchedule.forNow(PrayerTimes? times, DateTime now) =>
      (times == null ? null : fromPrayerTimes(times, now)) ??
      ThemeSchedule.approximate(now);

  ThemePeriod periodAt(DateTime now) {
    var period = ThemePeriod.isha;
    for (final s in slots) {
      if (s.start.isAfter(now)) break;
      period = s.period;
    }
    return period;
  }

  /// The next moment the look changes, or null when the schedule has run out
  /// (the caller re-reads prayer times then).
  DateTime? nextChangeAfter(DateTime now) {
    for (final s in slots) {
      if (s.start.isAfter(now)) return s.start;
    }
    return null;
  }

  static DateTime _earlier(DateTime a, DateTime b) => a.isBefore(b) ? a : b;
}
