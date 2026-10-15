import '../../domain/entities/prayer_times.dart';
import '../../domain/entities/prayer_times_bundle.dart';

/// Parsing for the backend's prayer-times responses (`{location, method,
/// days: [...]}`), shared by the guest and signed-in endpoints.
///
/// Each day carries six UTC instants plus `local.*` text with the zone's
/// offset (`2026-10-14T04:44:00+05:00`). The instants become [DateTime]s
/// (shown in the device zone by Dart); the offset is read from the text so
/// screens can display the prayer location's clock, not the phone's.
class PrayerTimesBundleModel {
  /// The response's `data` object, kept verbatim: it is exactly what the
  /// cache stores, so a cached bundle parses through the same code.
  final Map<String, dynamic> raw;

  const PrayerTimesBundleModel(this.raw);

  factory PrayerTimesBundleModel.fromJson(Map<String, dynamic> json) =>
      PrayerTimesBundleModel(json);

  Map<String, dynamic> toJson() => raw;

  PrayerTimesBundle toEntity() {
    final rawDays = (raw['days'] as List).cast<Map<String, dynamic>>();
    final days = <PrayerTimesDay>[];
    for (var i = 0; i < rawDays.length; i++) {
      final next = i + 1 < rawDays.length ? rawDays[i + 1] : null;
      days.add(
        PrayerTimesDay(
          date: rawDays[i]['date'] as String,
          times: prayerTimesFromJson(
            rawDays[i],
            nextFajr: next == null
                ? null
                : DateTime.parse(next['fajr'] as String).toLocal(),
          ),
        ),
      );
    }
    return PrayerTimesBundle(
      location: _location(raw['location'] as Map<String, dynamic>),
      method: _method(raw['method'] as Map<String, dynamic>),
      days: days,
      lockedDates: [
        for (final d in (raw['lockedDates'] as List? ?? const [])) d as String,
      ],
    );
  }
}

PrayerLocation _location(Map<String, dynamic> j) => PrayerLocation(
  latitude: (j['latitude'] as num).toDouble(),
  longitude: (j['longitude'] as num).toDouble(),
  timezone: j['timezone'] as String? ?? '',
);

CalculationMethodInfo _method(Map<String, dynamic> j) => CalculationMethodInfo(
  id: (j['id'] as num).toInt(),
  name: j['name'] as String? ?? '',
  school: j['school'] as String? ?? '',
  schoolId: (j['schoolId'] as num).toInt(),
);

PrayerTimes prayerTimesFromJson(
  Map<String, dynamic> day, {
  DateTime? nextFajr,
}) {
  DateTime instant(String key) => DateTime.parse(day[key] as String).toLocal();
  final local = day['local'] as Map<String, dynamic>;
  return PrayerTimes(
    fajr: instant('fajr'),
    sunrise: instant('sunrise'),
    dhuhr: instant('dhuhr'),
    asr: instant('asr'),
    maghrib: instant('maghrib'),
    isha: instant('isha'),
    hijriDate: hijriLabel(day['hijri'] as Map<String, dynamic>?),
    // Dhuhr sits mid-day, so it carries the offset in force for the day.
    utcOffset: offsetOf(local['dhuhr'] as String?),
    nextFajr: nextFajr,
  );
}

/// "3 Jumādá al-ūlá 1448 AH", or empty when the provider sent no Hijri date.
String hijriLabel(Map<String, dynamic>? hijri) {
  if (hijri == null) return '';
  final name = hijri['monthName'] as String? ?? '';
  return '${hijri['day']} $name ${hijri['year']} AH'.replaceAll('  ', ' ');
}

/// The UTC offset written at the end of an ISO string: `+05:00`, `-03:30`,
/// or `Z`. Null when the text has none.
Duration? offsetOf(String? iso) {
  if (iso == null) return null;
  if (iso.endsWith('Z')) return Duration.zero;
  final m = RegExp(r'([+-])(\d{2}):?(\d{2})$').firstMatch(iso);
  if (m == null) return null;
  final minutes = int.parse(m.group(2)!) * 60 + int.parse(m.group(3)!);
  return Duration(minutes: m.group(1) == '-' ? -minutes : minutes);
}

PrayerCity prayerCityFromJson(Map<String, dynamic> j) => PrayerCity(
  name: j['name'] as String? ?? '',
  region: j['region'] as String? ?? '',
  country: j['country'] as String? ?? '',
  countryCode: j['countryCode'] as String? ?? '',
  latitude: (j['latitude'] as num).toDouble(),
  longitude: (j['longitude'] as num).toDouble(),
  timezone: j['timezone'] as String? ?? '',
);

CalculationMethodOption methodOptionFromJson(Map<String, dynamic> j) =>
    CalculationMethodOption(
      id: (j['id'] as num).toInt(),
      name: j['name'] as String? ?? '',
    );

/// `GET /prayers/location`. `location` and `method` are null (or the whole
/// object is empty) before the first `PUT /prayers/location`.
SavedPrayerSettings savedSettingsFromJson(Map<String, dynamic> j) {
  final loc = j['location'] as Map<String, dynamic>?;
  final method = j['method'] as Map<String, dynamic>?;
  return SavedPrayerSettings(
    location: loc == null ? null : _location(loc),
    method: method == null ? null : _method(method),
  );
}
