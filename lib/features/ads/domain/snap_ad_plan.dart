import 'dart:math';

/// Which snap-viewing moments of a day get an interstitial.
///
/// A person can open one snap per prayer, five a day, but ads show only on
/// three of them, picked at random for the day. No prayer is special: Fajr
/// and Asr are as likely as the rest. The pick is made once per local day and
/// kept, so reopening the app never re-rolls it.
class SnapAdPlan {
  static const adsPerDay = 3;

  /// The prayers a snap can belong to, by `PrayerName.name`.
  static const prayers = ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha'];

  final String day;
  final Set<String> picked;
  final Set<String> shown;

  const SnapAdPlan({
    required this.day,
    required this.picked,
    this.shown = const {},
  });

  /// A fresh plan for [day] (`yyyy-MM-dd`).
  factory SnapAdPlan.draw(String day, Random random) {
    final shuffled = [...prayers]..shuffle(random);
    return SnapAdPlan(day: day, picked: shuffled.take(adsPerDay).toSet());
  }

  /// An ad is due for [prayer]: it was picked and hasn't been shown yet.
  bool isDue(String prayer) =>
      picked.contains(prayer) && !shown.contains(prayer);

  SnapAdPlan markShown(String prayer) =>
      SnapAdPlan(day: day, picked: picked, shown: {...shown, prayer});

  static String dayKey(DateTime time) =>
      '${time.year.toString().padLeft(4, '0')}-'
      '${time.month.toString().padLeft(2, '0')}-'
      '${time.day.toString().padLeft(2, '0')}';

  Map<String, dynamic> toJson() => {
    'day': day,
    'picked': picked.toList(),
    'shown': shown.toList(),
  };

  static SnapAdPlan? fromJson(Object? json) {
    if (json is! Map) return null;
    final day = json['day'];
    final picked = json['picked'];
    final shown = json['shown'];
    if (day is! String || picked is! List || shown is! List) return null;
    return SnapAdPlan(
      day: day,
      picked: picked.whereType<String>().toSet(),
      shown: shown.whereType<String>().toSet(),
    );
  }
}
