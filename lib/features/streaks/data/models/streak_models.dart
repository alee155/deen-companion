import '../../../groups/domain/entities/group.dart';
import '../../../prayer_times/domain/entities/prayer_times.dart';
import '../../domain/entities/group_streaks.dart';
import '../../domain/entities/my_streaks.dart';
import '../../domain/entities/streak_rule.dart';

int _int(Object? v) => (v as num).toInt();

/// `{ minPrayers, effectiveFrom, nextChange: null }`.
StreakRule streakRuleFromJson(Map<String, dynamic> json) => StreakRule(
  minPrayers: _int(json['minPrayers']),
  effectiveFrom: DateTime.parse(json['effectiveFrom'] as String),
);

MemberStreak memberStreakFromJson(Map<String, dynamic> json) => MemberStreak(
  userId: json['userId'] as String,
  name: json['name'] as String? ?? '',
  role: GroupRole.parse(json['role'] as String?),
  currentStreak: _int(json['currentStreak']),
  bestStreak: _int(json['bestStreak']),
  todayCount: _int(json['todayCount']),
  todayRequired: _int(json['todayRequired']),
  todayQualified: json['todayQualified'] as bool,
);

GroupStreakBoard groupStreakBoardFromJson(List<dynamic> list) =>
    GroupStreakBoard([
      for (final e in list) memberStreakFromJson(e as Map<String, dynamic>),
    ]);

/// `{ groups: [...], prayers: { fajr: {currentStreak, bestStreak}, … } }`.
/// A prayer name this app does not know is skipped, never an error.
MyStreaks myStreaksFromJson(Map<String, dynamic> json) {
  final prayers = <PrayerName, PrayerStreak>{};
  final raw = json['prayers'];
  if (raw is Map) {
    for (final p in PrayerName.values) {
      final entry = raw[p.name];
      if (entry is Map) {
        prayers[p] = PrayerStreak(
          currentStreak: _int(entry['currentStreak']),
          bestStreak: _int(entry['bestStreak']),
        );
      }
    }
  }
  return MyStreaks(
    groups: [
      for (final g in json['groups'] as List<dynamic>)
        GroupStreakSummary(
          groupId: (g as Map<String, dynamic>)['groupId'] as String,
          name: g['name'] as String? ?? '',
          currentStreak: _int(g['currentStreak']),
          bestStreak: _int(g['bestStreak']),
          minPrayers: _int(g['minPrayers']),
        ),
    ],
    prayers: prayers,
  );
}
