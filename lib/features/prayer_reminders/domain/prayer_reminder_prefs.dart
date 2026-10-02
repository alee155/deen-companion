import 'dart:convert';

import '../../prayer_times/domain/entities/prayer_times.dart';

/// How one prayer's reminder behaves. Persisted in Flutter, then pushed to
/// the native alarm scheduler with every schedule — native stays the only
/// thing that arms, rings, snoozes and cancels alarms.
class PrayerReminderPrefs {
  final bool enabled;
  final bool snoozeEnabled;
  final int snoozeMinutes;

  const PrayerReminderPrefs({
    this.enabled = true,
    this.snoozeEnabled = true,
    this.snoozeMinutes = 10,
  });

  static const defaults = PrayerReminderPrefs();

  /// Offered durations. Kept short on purpose — a snooze longer than this
  /// would risk running into the next prayer.
  static const snoozeOptions = [5, 10, 15, 20];

  PrayerReminderPrefs copyWith({
    bool? enabled,
    bool? snoozeEnabled,
    int? snoozeMinutes,
  }) => PrayerReminderPrefs(
    enabled: enabled ?? this.enabled,
    snoozeEnabled: snoozeEnabled ?? this.snoozeEnabled,
    snoozeMinutes: snoozeMinutes ?? this.snoozeMinutes,
  );

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'snoozeEnabled': snoozeEnabled,
    'snoozeMinutes': snoozeMinutes,
  };

  factory PrayerReminderPrefs.fromJson(Map<String, dynamic> json) =>
      PrayerReminderPrefs(
        enabled: json['enabled'] as bool? ?? true,
        snoozeEnabled: json['snoozeEnabled'] as bool? ?? true,
        snoozeMinutes: json['snoozeMinutes'] as int? ?? 10,
      );

  @override
  bool operator ==(Object other) =>
      other is PrayerReminderPrefs &&
      other.enabled == enabled &&
      other.snoozeEnabled == snoozeEnabled &&
      other.snoozeMinutes == snoozeMinutes;

  @override
  int get hashCode => Object.hash(enabled, snoozeEnabled, snoozeMinutes);
}

typedef PrayerPrefsMap = Map<PrayerName, PrayerReminderPrefs>;

PrayerPrefsMap defaultPrayerPrefs() => {
  for (final p in PrayerName.values) p: PrayerReminderPrefs.defaults,
};

String encodePrayerPrefs(PrayerPrefsMap prefs) =>
    jsonEncode({for (final e in prefs.entries) e.key.name: e.value.toJson()});

PrayerPrefsMap decodePrayerPrefs(String? raw) {
  final result = defaultPrayerPrefs();
  if (raw == null) return result;
  try {
    final json = jsonDecode(raw) as Map<String, dynamic>;
    for (final prayer in PrayerName.values) {
      final entry = json[prayer.name];
      if (entry is Map<String, dynamic>) {
        result[prayer] = PrayerReminderPrefs.fromJson(entry);
      }
    }
  } catch (_) {
    // Corrupt value: fall back to defaults rather than losing reminders.
  }
  return result;
}
