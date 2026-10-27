/// A ringing prayer alarm the user opened the app from (iOS: the "Open"
/// button on the system alarm screen).
class PrayerAlarmLaunch {
  /// Lower-case prayer id as the schedule uses it: `fajr`, `dhuhr`, ...
  final String prayerName;
  final String label;
  final DateTime time;

  /// How long Snooze waits; 0 or less when the prayer has snooze switched off.
  final int snoozeMinutes;

  const PrayerAlarmLaunch({
    required this.prayerName,
    required this.label,
    required this.time,
    required this.snoozeMinutes,
  });

  bool get canSnooze => snoozeMinutes > 0;

  /// `fajr` -> `Fajr`.
  String get displayName => prayerName.isEmpty
      ? 'Prayer'
      : prayerName[0].toUpperCase() + prayerName.substring(1);

  /// Null when the platform sent something unusable.
  static PrayerAlarmLaunch? fromMap(Map<Object?, Object?> map) {
    final prayer = map['prayerName'];
    final millis = map['epochMillis'];
    if (prayer is! String || millis is! num) return null;
    final minutes = map['snoozeMinutes'];
    return PrayerAlarmLaunch(
      prayerName: prayer,
      label: map['label'] is String ? map['label'] as String : prayer,
      time: DateTime.fromMillisecondsSinceEpoch(millis.toInt()),
      snoozeMinutes: minutes is num ? minutes.toInt() : 0,
    );
  }
}
