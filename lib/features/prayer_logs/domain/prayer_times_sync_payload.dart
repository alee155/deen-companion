import '../../prayer_times/domain/entities/prayer_times.dart';

/// Builds and sanity-checks the body of `PUT /prayers/times`, mirroring the
/// server's rules so one bad day is dropped here instead of failing the whole
/// request (the server applies nothing if any day is rejected).
class PrayerTimesSyncPayload {
  PrayerTimesSyncPayload._();

  /// The server accepts 1–8 days: the user's local today through today + 7.
  static const maxDays = 8;
  static const minWindow = Duration(minutes: 5);

  /// Days to upload from [candidates] (any order, may span past/future),
  /// relative to the device's local [now]. Each entry is a JSON-ready day.
  static List<Map<String, String>> build(
    Iterable<PrayerTimes> candidates,
    DateTime now,
  ) {
    final today = DateTime(now.year, now.month, now.day);
    final last = DateTime(now.year, now.month, now.day + maxDays - 1);

    final byDate = <DateTime, PrayerTimes>{};
    for (final day in candidates) {
      final date = DateTime(day.fajr.year, day.fajr.month, day.fajr.day);
      if (date.isBefore(today) || date.isAfter(last)) continue;
      if (day.sunrise == null) continue;
      byDate.putIfAbsent(date, () => day);
    }

    final dates = byDate.keys.toList()..sort();
    final valid = <DateTime, PrayerTimes>{
      for (final d in dates)
        if (isValid(byDate[d]!)) d: byDate[d]!,
    };

    // A day must end before the next calendar day's Fajr begins.
    final result = <Map<String, String>>[];
    DateTime? previousIsha;
    for (final d in valid.keys) {
      final day = valid[d]!;
      if (previousIsha != null && !day.fajr.isAfter(previousIsha)) continue;
      previousIsha = day.isha;
      result.add(_toJson(d, day));
    }
    return result;
  }

  /// Strictly ascending times, every gap at least [minWindow], and Fajr to
  /// Isha under 24 hours.
  static bool isValid(PrayerTimes day) {
    final times = [
      day.fajr,
      day.sunrise,
      day.dhuhr,
      day.asr,
      day.maghrib,
      day.isha,
    ];
    if (times.contains(null)) return false;
    for (var i = 1; i < times.length; i++) {
      if (times[i]!.difference(times[i - 1]!) < minWindow) return false;
    }
    return day.isha.difference(day.fajr) < const Duration(hours: 24);
  }

  static Map<String, String> _toJson(DateTime date, PrayerTimes day) => {
    'date': _date(date),
    'fajr': isoWithOffset(day.fajr),
    'sunrise': isoWithOffset(day.sunrise!),
    'dhuhr': isoWithOffset(day.dhuhr),
    'asr': isoWithOffset(day.asr),
    'maghrib': isoWithOffset(day.maghrib),
    'isha': isoWithOffset(day.isha),
  };

  /// One readable line per day for the debug log: what Aladhan gave us, as
  /// plain device-local clock times (no offset), `--:--` where a time is
  /// missing.
  static String describeReceived(PrayerTimes d) {
    String hm(DateTime? t) =>
        t == null ? '--:--' : '${_two(t.hour)}:${_two(t.minute)}';
    return '${_date(d.fajr)}  fajr ${hm(d.fajr)}  sunrise ${hm(d.sunrise)}  '
        'dhuhr ${hm(d.dhuhr)}  asr ${hm(d.asr)}  maghrib ${hm(d.maghrib)}  '
        'isha ${hm(d.isha)}';
  }

  /// Date `yyyy-MM-dd` of a day's Fajr, the key `build` groups by.
  static String dateOf(PrayerTimes d) => _date(d.fajr);

  static String _date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${_two(d.month)}-${_two(d.day)}';

  /// `2026-10-07T04:51:00+05:00` — Dart's own `toIso8601String` omits the
  /// offset for local times, and the server needs it.
  static String isoWithOffset(DateTime t) {
    final offset = t.timeZoneOffset;
    final sign = offset.isNegative ? '-' : '+';
    final abs = offset.abs();
    final hh = _two(abs.inHours);
    final mm = _two(abs.inMinutes.remainder(60));
    return '${_date(t)}T${_two(t.hour)}:${_two(t.minute)}:${_two(t.second)}'
        '$sign$hh:$mm';
  }

  static String _two(int n) => n.toString().padLeft(2, '0');
}
