import 'package:equatable/equatable.dart';

import '../../../prayer_times/domain/entities/prayer_times.dart';

/// How many points one prayer is worth when it is logged.
class PointsRule extends Equatable {
  /// The server's name for the prayer (`fajr`, `dhuhr`, …). Kept as text so a
  /// prayer this app does not know yet still shows up instead of vanishing.
  final String prayer;
  final int points;

  const PointsRule({required this.prayer, required this.points});

  /// The prayer as the app's enum, or null for one it does not know.
  PrayerName? get prayerName {
    for (final p in PrayerName.values) {
      if (p.name == prayer) return p;
    }
    return null;
  }

  @override
  List<Object?> get props => [prayer, points];
}

/// The full rule table, in display order: Fajr to Isha, then anything else the
/// server adds in the order it sent it.
class PointsRules extends Equatable {
  final List<PointsRule> rules;

  const PointsRules._(this.rules);

  factory PointsRules(Iterable<PointsRule> rules) {
    final known = <PointsRule>[];
    final other = <PointsRule>[];
    for (final r in rules) {
      (r.prayerName == null ? other : known).add(r);
    }
    known.sort((a, b) => a.prayerName!.index.compareTo(b.prayerName!.index));
    return PointsRules._([...known, ...other]);
  }

  bool get isEmpty => rules.isEmpty;

  /// What a day earns when every prayer in the table is logged.
  int get total => rules.fold(0, (sum, r) => sum + r.points);

  /// The most any single prayer earns; 0 when there are no rules.
  int get highest =>
      rules.fold(0, (best, r) => r.points > best ? r.points : best);

  @override
  List<Object?> get props => [rules];
}
