import '../../domain/entities/prayer_times.dart';

/// Maps the Aladhan API's timings response into our domain entity.
/// Kept as a plain class (not freezed) since it's a one-way parse with
/// no equality/copyWith needs — a good example of not reaching for
/// codegen when it doesn't earn its keep.
class PrayerTimesModel {
  final PrayerTimes toEntity;

  const PrayerTimesModel._(this.toEntity);

  factory PrayerTimesModel.fromJson(Map<String, dynamic> json) {
    final timings = json['data']['timings'] as Map<String, dynamic>;
    final hijri = json['data']['date']['hijri'];
    final gregorianDateStr =
        json['data']['date']['gregorian']['date'] as String; // "06-07-2026"

    final dateParts = gregorianDateStr.split('-'); // [dd, mm, yyyy]
    final day = int.parse(dateParts[0]);
    final month = int.parse(dateParts[1]);
    final year = int.parse(dateParts[2]);

    DateTime parseTime(String key) {
      final raw = (timings[key] as String)
          .split(' ')
          .first; // strips " (PKT)" suffix if present
      final parts = raw.split(':');
      return DateTime(
        year,
        month,
        day,
        int.parse(parts[0]),
        int.parse(parts[1]),
      );
    }

    final hijriDateStr =
        '${hijri['day']} ${hijri['month']['en']} ${hijri['year']} AH';

    return PrayerTimesModel._(
      PrayerTimes(
        fajr: parseTime('Fajr'),
        dhuhr: parseTime('Dhuhr'),
        asr: parseTime('Asr'),
        maghrib: parseTime('Maghrib'),
        isha: parseTime('Isha'),
        hijriDate: hijriDateStr,
      ),
    );
  }
}
