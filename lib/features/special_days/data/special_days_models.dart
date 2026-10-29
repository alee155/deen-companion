import '../../prayer_times/domain/entities/prayer_times.dart';
import '../domain/special_days.dart';

/// `data` of the `/exemption` endpoints. A male or unset account only gets
/// `{eligible: false, genderSet}`, so every field but `eligible` is optional.
SpecialDays specialDaysFromJson(Map<String, dynamic> json) {
  DateTime? time(Object? v) => v is String ? DateTime.tryParse(v) : null;
  String? text(Object? v) => v is String && v.isNotEmpty ? v : null;

  final rawImages = json['images'];
  final images = <PrayerName, bool>{
    if (rawImages is Map)
      for (final p in PrayerName.values) p: rawImages[p.name] == true,
  };

  return SpecialDays(
    eligible: json['eligible'] == true,
    active: json['active'] == true,
    startedAt: time(json['startedAt']),
    startLocalDate: text(json['startLocalDate']),
    endsLocalDate: text(json['endsLocalDate']),
    endsAt: time(json['endsAt']),
    daysRemaining: (json['daysRemaining'] as num?)?.toInt(),
    images: images,
    canStartAt: time(json['canStartAt']),
    infoMessage: text(json['infoMessage']),
  );
}

/// `data` of `GET /exemption/images`:
/// `{images: {fajr..isha: {url, updatedAt} | null}}`. A prayer with no photo is
/// simply left out of the result; so is one whose entry can't be read.
Map<PrayerName, SpecialDayImage> specialDayImagesFromJson(
  Map<String, dynamic> json,
) {
  final raw = json['images'];
  if (raw is! Map) return const {};
  final out = <PrayerName, SpecialDayImage>{};
  for (final p in PrayerName.values) {
    final entry = raw[p.name];
    if (entry is! Map) continue;
    final url = entry['url'] is String
        ? Uri.tryParse(entry['url'] as String)
        : null;
    final at = entry['updatedAt'] is String
        ? DateTime.tryParse(entry['updatedAt'] as String)
        : null;
    if (url == null || !url.hasScheme || at == null) continue;
    out[p] = SpecialDayImage(url: url, updatedAt: at.toUtc());
  }
  return out;
}
