import 'package:equatable/equatable.dart';

import 'prayer_times.dart';

/// Where prayer times are calculated for, as the server reports it. The time
/// zone comes from the location, never from the phone.
class PrayerLocation extends Equatable {
  final double latitude;
  final double longitude;
  final String timezone;

  const PrayerLocation({
    required this.latitude,
    required this.longitude,
    required this.timezone,
  });

  @override
  List<Object?> get props => [latitude, longitude, timezone];
}

/// The calculation method and Asr school the times were produced with.
class CalculationMethodInfo extends Equatable {
  final int id;
  final String name;

  /// `hanafi` or `standard` (Shafi'i, Maliki, Hanbali).
  final String school;

  /// 1 = Hanafi, 0 = Shafi'i/standard — the value to send back as `school`.
  final int schoolId;

  const CalculationMethodInfo({
    required this.id,
    required this.name,
    required this.school,
    required this.schoolId,
  });

  /// "Calculated: Karachi method, Hanafi Asr".
  String get sourceLabel =>
      'Calculated: $name, ${schoolId == 1 ? 'Hanafi' : 'Shafi'} Asr';

  @override
  List<Object?> get props => [id, name, school, schoolId];
}

/// What one times request returns: the days plus how they were calculated.
class PrayerTimesBundle extends Equatable {
  final PrayerLocation location;
  final CalculationMethodInfo method;
  final List<PrayerTimesDay> days;

  /// Days kept as they were because a prayer is already logged on them. Only
  /// filled by `PUT /prayers/location`.
  final List<String> lockedDates;

  const PrayerTimesBundle({
    required this.location,
    required this.method,
    required this.days,
    this.lockedDates = const [],
  });

  @override
  List<Object?> get props => [location, method, days, lockedDates];
}

/// One calendar day of the bundle: its `yyyy-MM-dd` date and the times.
class PrayerTimesDay extends Equatable {
  final String date;
  final PrayerTimes times;
  const PrayerTimesDay({required this.date, required this.times});

  @override
  List<Object?> get props => [date, times];
}

/// A city from the search endpoint, for users who deny location permission.
class PrayerCity extends Equatable {
  final String name;
  final String region;
  final String country;
  final String countryCode;
  final double latitude;
  final double longitude;
  final String timezone;

  const PrayerCity({
    required this.name,
    required this.region,
    required this.country,
    required this.countryCode,
    required this.latitude,
    required this.longitude,
    required this.timezone,
  });

  /// "Lahore, Punjab, Pakistan" — enough to tell same-named cities apart.
  String get label => [
    name,
    if (region.isNotEmpty && region != name) region,
    country,
  ].where((p) => p.isNotEmpty).join(', ');

  @override
  List<Object?> get props => [
    name,
    region,
    country,
    countryCode,
    latitude,
    longitude,
    timezone,
  ];
}

/// One entry of `GET /prayer-times/methods`.
class CalculationMethodOption extends Equatable {
  final int id;
  final String name;
  const CalculationMethodOption({required this.id, required this.name});

  @override
  List<Object?> get props => [id, name];
}

/// `GET /prayers/location`: what the account has saved. Both null before the
/// first `PUT /prayers/location`.
class SavedPrayerSettings extends Equatable {
  final PrayerLocation? location;
  final CalculationMethodInfo? method;
  const SavedPrayerSettings({this.location, this.method});

  @override
  List<Object?> get props => [location, method];
}
