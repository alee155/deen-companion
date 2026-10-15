import 'package:equatable/equatable.dart';

enum PrayerName { fajr, dhuhr, asr, maghrib, isha }

class PrayerTimes extends Equatable {
  final DateTime fajr;

  /// Null for timings cached before sunrise was parsed.
  final DateTime? sunrise;
  final DateTime dhuhr;
  final DateTime asr;
  final DateTime maghrib;
  final DateTime isha;
  final String hijriDate;

  /// UTC offset of the place these times were calculated for (`+05:00`).
  /// Null means "the device's own zone" — the case for anything built
  /// without server data. The DateTimes above are instants (shown in the
  /// device's zone by Dart); [wallClock] gives the clock face at the prayer
  /// location, which is what the screens display.
  final Duration? utcOffset;

  /// Fajr of the following day, when known, so "next prayer" after Isha
  /// points at the real time instead of today's Fajr plus 24 hours.
  final DateTime? nextFajr;

  const PrayerTimes({
    required this.fajr,
    this.sunrise,
    required this.dhuhr,
    required this.asr,
    required this.maghrib,
    required this.isha,
    required this.hijriDate,
    this.utcOffset,
    this.nextFajr,
  });

  /// [t] as a clock reading at the prayer location: format this with
  /// `DateFormat`, never the raw instant, so a phone set to another timezone
  /// still shows the times the prayer place is actually on.
  DateTime wallClock(DateTime t) {
    final offset = utcOffset;
    return offset == null ? t.toLocal() : t.toUtc().add(offset);
  }

  List<MapEntry<PrayerName, DateTime>> get _ordered => [
    MapEntry(PrayerName.fajr, fajr),
    MapEntry(PrayerName.dhuhr, dhuhr),
    MapEntry(PrayerName.asr, asr),
    MapEntry(PrayerName.maghrib, maghrib),
    MapEntry(PrayerName.isha, isha),
  ];

  /// The next upcoming prayer relative to [now]. Falls back to tomorrow's
  /// Fajr if every prayer today has already passed.
  MapEntry<PrayerName, DateTime> nextPrayer(DateTime now) {
    for (final entry in _ordered) {
      if (entry.value.isAfter(now)) return entry;
    }
    return MapEntry(
      PrayerName.fajr,
      nextFajr ?? fajr.add(const Duration(days: 1)),
    );
  }

  Duration timeUntilNextPrayer(DateTime now) {
    return nextPrayer(now).value.difference(now);
  }

  @override
  List<Object?> get props => [
    fajr,
    sunrise,
    dhuhr,
    asr,
    maghrib,
    isha,
    hijriDate,
    utcOffset,
    nextFajr,
  ];
}
