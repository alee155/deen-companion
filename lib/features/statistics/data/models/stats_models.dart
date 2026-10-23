import '../../../groups/domain/entities/group.dart';
import '../../../prayer_times/domain/entities/prayer_times.dart';
import '../../domain/entities/group_stats.dart';
import '../../domain/entities/personal_stats.dart';
import '../../domain/entities/stats_common.dart';

// The shapes below follow the Statistics API reference. A missing or mistyped
// required field throws a TypeError, which the data source reports as a server
// error instead of showing a made-up zero.

int _int(Object? v) => (v as num).toInt();
double? _pct(Object? v) => (v as num?)?.toDouble();
Map<String, dynamic> _map(Object? v) => v as Map<String, dynamic>;
List<Map<String, dynamic>> _list(Object? v) => [
  for (final e in v as List<dynamic>) _map(e),
];

StatsRange rangeFromJson(Object? j) {
  final m = _map(j);
  return StatsRange(from: m['from'] as String, to: m['to'] as String);
}

PeriodTotals totalsFromJson(Object? j) {
  final m = _map(j);
  return PeriodTotals(
    prayersLogged: _int(m['prayersLogged']),
    points: _int(m['points']),
    activeDays: _int(m['activeDays']),
    perfectDays: _int(m['perfectDays']),
  );
}

Completion completionFromJson(Object? j) {
  final m = _map(j);
  return Completion(
    percent: _pct(m['percent']),
    loggedPrayers: _int(m['loggedPrayers']),
    possiblePrayers: _int(m['possiblePrayers']),
    completedDays: _int(m['completedDays']),
  );
}

/// A prayer the app does not know is skipped (a new one must not break the
/// screen).
List<PrayerStat> perPrayerFromJson(Object? j) => [
  for (final m in _list(j))
    if (prayerFromName(m['prayer'] as String?) case final p?)
      PrayerStat(
        prayer: p,
        count: _int(m['count']),
        percentOfCompletedDays: _pct(m['percentOfCompletedDays']),
        points: _int(m['points']),
        currentStreak: (m['currentStreak'] as num?)?.toInt(),
        bestStreak: (m['bestStreak'] as num?)?.toInt(),
      ),
];

DailyStat dailyFromJson(Map<String, dynamic> m) {
  final prayers = <PrayerName, bool>{};
  final raw = m['prayers'];
  if (raw is Map) {
    for (final p in PrayerName.values) {
      prayers[p] = raw[p.name] == true;
    }
  }
  return DailyStat(
    date: m['date'] as String,
    prayersLogged: _int(m['prayersLogged']),
    points: _int(m['points']),
    prayers: prayers,
    isToday: m['isToday'] == true,
  );
}

List<DailyStat> dailyListFromJson(Object? j) => [
  for (final m in _list(j)) dailyFromJson(m),
];

PersonalSummary personalSummaryFromJson(Object? j) {
  final m = _map(j);
  return PersonalSummary(
    range: rangeFromJson(m['range']),
    totals: totalsFromJson(m['totals']),
    completion: completionFromJson(m['completion']),
    perPrayer: perPrayerFromJson(m['perPrayer']),
    strongest: prayerFromName(m['strongestPrayer'] as String?),
    weakest: prayerFromName(m['weakestPrayer'] as String?),
  );
}

List<TrendPoint> trendFromJson(Object? j) => [
  for (final m in _list(j))
    TrendPoint(
      periodStart: m['periodStart'] as String,
      periodEnd: m['periodEnd'] as String,
      label: m['label'] as String? ?? '',
      prayersLogged: _int(m['prayersLogged']),
      points: _int(m['points']),
      activeDays: _int(m['activeDays']),
      perfectDays: _int(m['perfectDays']),
      completionPercent: _pct(m['completionPercent']),
      isCurrent: m['isCurrent'] == true,
    ),
];

GroupOverview groupOverviewFromJson(Object? j) {
  final m = _map(j);
  final t = _map(m['totals']);
  return GroupOverview(
    memberCount: _int(m['memberCount']),
    totals: GroupTotals(
      prayersLogged: _int(t['prayersLogged']),
      points: _int(t['points']),
      perfectMemberDays: _int(t['perfectMemberDays']),
      membersActiveToday: _int(t['membersActiveToday']),
    ),
    averageParticipationPercent: _pct(m['averageParticipationPercent']),
    daily: [
      for (final d in _list(m['daily']))
        GroupDay(
          date: d['date'] as String,
          prayersLogged: _int(d['prayersLogged']),
          points: _int(d['points']),
          membersQualified: _int(d['membersQualified']),
          membersTotal: _int(d['membersTotal']),
          participationPercent: _pct(d['participationPercent']),
          isToday: d['isToday'] == true,
        ),
    ],
  );
}

List<GroupMemberStat> groupMembersFromJson(Object? j) => [
  for (final m in _list(j))
    GroupMemberStat(
      userId: m['userId'] as String,
      name: m['name'] as String? ?? '',
      role: GroupRole.parse(m['role'] as String?),
      prayersLogged: _int(m['prayersLogged']),
      points: _int(m['points']),
      activeDays: _int(m['activeDays']),
      perfectDays: _int(m['perfectDays']),
      completionPercent: _pct(m['completionPercent']),
      currentStreak: _int(m['currentStreak']),
    ),
];

MemberStatsDetail memberDetailFromJson(Object? j) {
  final m = _map(j);
  final who = _map(m['member']);
  final joined = who['joinedAt'] as String?;
  return MemberStatsDetail(
    member: MemberIdentity(
      userId: who['userId'] as String,
      name: who['name'] as String? ?? '',
      role: GroupRole.parse(who['role'] as String?),
      joinedAt: joined == null ? null : DateTime.parse(joined),
    ),
    range: rangeFromJson(m['range']),
    totals: totalsFromJson(m['totals']),
    completion: completionFromJson(m['completion']),
    daily: dailyListFromJson(m['daily']),
    perPrayer: perPrayerFromJson(m['perPrayer']),
  );
}

/// A flag this app does not know is dropped; a member left with no known flag
/// is dropped too (there would be nothing to say about them).
AttentionReport attentionFromJson(Object? j) {
  final m = _map(j);
  final members = <AttentionMember>[];
  for (final a in _list(m['members'])) {
    final flags = [
      for (final f in a['flags'] as List<dynamic>)
        ?AttentionFlag.parse(f as String?),
    ];
    if (flags.isEmpty) continue;
    members.add(
      AttentionMember(
        userId: a['userId'] as String,
        name: a['name'] as String? ?? '',
        flags: flags,
        lastLoggedDate: a['lastLoggedDate'] as String?,
        daysSinceLastLog: (a['daysSinceLastLog'] as num?)?.toInt(),
        completionLast7: _pct(a['completionLast7']),
        completionPrev7: _pct(a['completionPrev7']),
      ),
    );
  }
  return AttentionReport(
    asOf: m['asOf'] as String,
    inactiveDaysThreshold: _int(m['inactiveDaysThreshold']),
    members: members,
  );
}
