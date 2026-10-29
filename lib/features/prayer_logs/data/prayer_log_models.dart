import '../../prayer_times/domain/entities/prayer_times.dart';
import '../../groups/domain/entities/group.dart';
import '../domain/current_prayer.dart';
import '../domain/group_member_prayers.dart';
import '../domain/prayer_log.dart';

PrayerName _prayer(Object? raw) => PrayerName.values.firstWhere(
  (p) => p.name == raw,
  orElse: () => throw FormatException('Unknown prayer: $raw'),
);

DateTime _time(Object? raw) => DateTime.parse(raw as String);

PrayerLog prayerLogFromJson(Map<String, dynamic> json) => PrayerLog(
  id: json['id'].toString(),
  prayer: _prayer(json['prayer']),
  date: json['date'] as String,
  status: PrayerLogStatus.parse(json['status'] as String?),
  points: (json['points'] as num?)?.toInt() ?? 0,
  snapUrl: json['snapUrl'] as String?,
  hasSnap: json['hasSnap'] == true,
  snapViewed: json['snapViewed'] == true,
  snapExpired: json['snapExpired'] == true,
  groupIds: [
    for (final id in (json['groupIds'] as List? ?? const [])) id.toString(),
  ],
  windowStartsAt: _time(json['windowStartsAt']),
  windowEndsAt: _time(json['windowEndsAt']),
  loggedAt: _time(json['loggedAt']),
  viewDurationSeconds: (json['viewDurationSeconds'] as num?)?.toInt(),
);

CurrentPrayerState currentPrayerStateFromJson(Map<String, dynamic> json) {
  final current = json['current'] as Map<String, dynamic>?;
  final next = json['next'] as Map<String, dynamic>?;
  return CurrentPrayerState(
    now: _time(json['now']),
    current: current == null
        ? null
        : CurrentPrayer(
            prayer: _prayer(current['prayer']),
            date: current['date'] as String,
            startsAt: _time(current['startsAt']),
            endsAt: _time(current['endsAt']),
            logged: current['logged'] as bool? ?? false,
            logId: current['logId'] as String?,
          ),
    next: next == null
        ? null
        : NextPrayer(
            prayer: _prayer(next['prayer']),
            startsAt: _time(next['startsAt']),
          ),
  );
}

GroupMemberPrayers groupMemberPrayersFromJson(Map<String, dynamic> json) =>
    GroupMemberPrayers(
      userId: json['userId'].toString(),
      name: json['name'] as String? ?? '',
      role: GroupRole.parse(json['role'] as String?),
      logs: [
        for (final l in (json['logs'] as List? ?? const []))
          prayerLogFromJson(l as Map<String, dynamic>),
      ],
    );
