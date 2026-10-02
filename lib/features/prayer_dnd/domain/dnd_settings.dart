import '../../prayer_times/domain/entities/prayer_times.dart';

/// Which editor the user is using to set per-prayer durations. Both write to
/// the same per-prayer [DndSettings.durations], so they can be mixed
/// (Fajr from a preset, Isha from the slider).
enum DndDurationMode { preset, custom }

class DndSettings {
  static const presetMinutes = [15, 20, 30, 45, 60];
  static const minCustomMinutes = 1;
  static const maxCustomMinutes = 120;
  static const defaultCustomMinutes = 15;

  final bool enabled;
  final DndDurationMode mode;

  /// Minutes of Do Not Disturb starting when each prayer begins. A prayer
  /// that is absent is not configured and never triggers DND.
  final Map<PrayerName, int> durations;

  const DndSettings({
    this.enabled = false,
    this.mode = DndDurationMode.preset,
    this.durations = const {},
  });

  int? minutesFor(PrayerName prayer) => durations[prayer];

  bool isConfigured(PrayerName prayer) => durations.containsKey(prayer);

  int get configuredCount => durations.length;

  DndSettings copyWith({
    bool? enabled,
    DndDurationMode? mode,
    Map<PrayerName, int>? durations,
  }) => DndSettings(
    enabled: enabled ?? this.enabled,
    mode: mode ?? this.mode,
    durations: durations ?? this.durations,
  );
}
