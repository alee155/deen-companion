import '../../domain/entities/prayer_times.dart';

class PrayerTimesModel {
  final DateTime fajr;
  final DateTime dhuhr;
  final DateTime asr;
  final DateTime maghrib;
  final DateTime isha;
  final String hijriDate;

  const PrayerTimesModel({
    required this.fajr,
    required this.dhuhr,
    required this.asr,
    required this.maghrib,
    required this.isha,
    required this.hijriDate,
  });

  factory PrayerTimesModel.fromApiJson(Map<String, dynamic> json) {
    final timings = json['data']['timings'] as Map<String, dynamic>;
    final hijri = json['data']['date']['hijri'];
    final gregorianDateStr =
        json['data']['date']['gregorian']['date'] as String;

    final dateParts = gregorianDateStr.split('-');
    final day = int.parse(dateParts[0]);
    final month = int.parse(dateParts[1]);
    final year = int.parse(dateParts[2]);

    DateTime parseTime(String key) {
      final raw = (timings[key] as String).split(' ').first;
      final parts = raw.split(':');
      return DateTime(
        year,
        month,
        day,
        int.parse(parts[0]),
        int.parse(parts[1]),
      );
    }

    return PrayerTimesModel(
      fajr: parseTime('Fajr'),
      dhuhr: parseTime('Dhuhr'),
      asr: parseTime('Asr'),
      maghrib: parseTime('Maghrib'),
      isha: parseTime('Isha'),
      hijriDate: '${hijri['day']} ${hijri['month']['en']} ${hijri['year']} AH',
    );
  }

  // For reading/writing our own cache — distinct from fromApiJson, since
  // the cached shape is flat and ISO-formatted, not the raw Aladhan envelope.
  factory PrayerTimesModel.fromJson(Map<String, dynamic> json) {
    return PrayerTimesModel(
      fajr: DateTime.parse(json['fajr'] as String),
      dhuhr: DateTime.parse(json['dhuhr'] as String),
      asr: DateTime.parse(json['asr'] as String),
      maghrib: DateTime.parse(json['maghrib'] as String),
      isha: DateTime.parse(json['isha'] as String),
      hijriDate: json['hijri_date'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
    'fajr': fajr.toIso8601String(),
    'dhuhr': dhuhr.toIso8601String(),
    'asr': asr.toIso8601String(),
    'maghrib': maghrib.toIso8601String(),
    'isha': isha.toIso8601String(),
    'hijri_date': hijriDate,
  };

  PrayerTimes toEntity() => PrayerTimes(
    fajr: fajr,
    dhuhr: dhuhr,
    asr: asr,
    maghrib: maghrib,
    isha: isha,
    hijriDate: hijriDate,
  );
}
