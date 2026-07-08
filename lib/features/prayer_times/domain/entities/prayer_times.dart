import 'package:equatable/equatable.dart';

enum PrayerName { fajr, dhuhr, asr, maghrib, isha }

class PrayerTimes extends Equatable {
  final DateTime fajr;
  final DateTime dhuhr;
  final DateTime asr;
  final DateTime maghrib;
  final DateTime isha;
  final String hijriDate;

  const PrayerTimes({
    required this.fajr,
    required this.dhuhr,
    required this.asr,
    required this.maghrib,
    required this.isha,
    required this.hijriDate,
  });

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
    return MapEntry(PrayerName.fajr, fajr.add(const Duration(days: 1)));
  }

  Duration timeUntilNextPrayer(DateTime now) {
    return nextPrayer(now).value.difference(now);
  }

  @override
  List<Object?> get props => [fajr, dhuhr, asr, maghrib, isha, hijriDate];
}
