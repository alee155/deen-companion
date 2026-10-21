import '../../prayer_times/domain/entities/prayer_times.dart';

/// Which editor the user is using to set per-prayer durations. Both write to
/// the same per-prayer [DndSettings.durations], so they can be mixed
/// (Fajr from a preset, Isha from the slider).
enum DndDurationMode { preset, custom }

/// A ready-made window shape: how long before the prayer DND starts and how
/// long it stays on after.
class DndPreset {
  final String name;
  final int leadMinutes;
  final int afterMinutes;

  const DndPreset(this.name, this.leadMinutes, this.afterMinutes);

  bool matches(int lead, int after) =>
      lead == leadMinutes && after == afterMinutes;
}

class DndSettings {
  static const presetMinutes = [15, 20, 30, 45, 60];
  static const minCustomMinutes = 1;
  static const maxCustomMinutes = 120;
  static const defaultCustomMinutes = 15;

  /// People silence their phone before the prayer, so DND may start this
  /// early at most.
  static const maxLeadMinutes = 30;
  static const defaultLeadMinutes = 5;

  static const presets = [
    DndPreset('Quick', 5, 15),
    DndPreset('Standard', 10, 20),
    DndPreset('Extended', 10, 45),
    DndPreset('Long', 15, 60),
  ];

  final bool enabled;
  final DndDurationMode mode;

  /// Minutes of Do Not Disturb starting when each prayer begins. A prayer
  /// that is absent is not configured and never triggers DND.
  final Map<PrayerName, int> durations;

  /// Minutes of DND *before* each prayer begins; absent means 0.
  final Map<PrayerName, int> leads;

  const DndSettings({
    this.enabled = false,
    this.mode = DndDurationMode.preset,
    this.durations = const {},
    this.leads = const {},
  });

  int? minutesFor(PrayerName prayer) => durations[prayer];

  int leadFor(PrayerName prayer) => leads[prayer] ?? 0;

  bool isConfigured(PrayerName prayer) => durations.containsKey(prayer);

  int get configuredCount => durations.length;

  DndSettings copyWith({
    bool? enabled,
    DndDurationMode? mode,
    Map<PrayerName, int>? durations,
    Map<PrayerName, int>? leads,
  }) => DndSettings(
    enabled: enabled ?? this.enabled,
    mode: mode ?? this.mode,
    durations: durations ?? this.durations,
    leads: leads ?? this.leads,
  );
}
