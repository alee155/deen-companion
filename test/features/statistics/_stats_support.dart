import 'package:deen_companion/core/error/failures.dart';
import 'package:deen_companion/core/usecase/usecase.dart';
import 'package:deen_companion/features/groups/domain/entities/group.dart';
import 'package:deen_companion/features/prayer_times/domain/entities/prayer_times.dart';
import 'package:deen_companion/features/statistics/domain/entities/group_stats.dart';
import 'package:deen_companion/features/statistics/domain/entities/personal_stats.dart';
import 'package:deen_companion/features/statistics/domain/entities/stats_common.dart';
import 'package:deen_companion/features/statistics/domain/repositories/statistics_repository.dart';

// ── JSON, as the API reference documents it ──

const rangeJson = {'from': '2026-09-20', 'to': '2026-10-19'};
const totalsJson = {
  'prayersLogged': 120,
  'points': 640,
  'activeDays': 25,
  'perfectDays': 10,
};
const completionJson = {
  'percent': 82.5,
  'loggedPrayers': 115,
  'possiblePrayers': 140,
  'completedDays': 28,
};
const perPrayerJson = [
  {
    'prayer': 'fajr',
    'count': 20,
    'percentOfCompletedDays': 71.4,
    'points': 200,
    'currentStreak': 12,
    'bestStreak': 30,
  },
  {
    'prayer': 'dhuhr',
    'count': 27,
    'percentOfCompletedDays': 96.4,
    'points': 135,
    'currentStreak': 3,
    'bestStreak': 9,
  },
];

Map<String, dynamic> summaryJson() => {
  'range': rangeJson,
  'totals': totalsJson,
  'completion': completionJson,
  'perPrayer': [...perPrayerJson],
  'strongestPrayer': 'dhuhr',
  'weakestPrayer': 'fajr',
};

List<Map<String, dynamic>> dailyJson() => [
  {
    'date': '2026-10-17',
    'prayersLogged': 5,
    'points': 30,
    'prayers': {
      'fajr': true,
      'dhuhr': true,
      'asr': true,
      'maghrib': true,
      'isha': true,
    },
    'isToday': false,
  },
  {
    'date': '2026-10-18',
    'prayersLogged': 0,
    'points': 0,
    'prayers': {
      'fajr': false,
      'dhuhr': false,
      'asr': false,
      'maghrib': false,
      'isha': false,
    },
    'isToday': false,
  },
  {
    'date': '2026-10-19',
    'prayersLogged': 2,
    'points': 15,
    'prayers': {
      'fajr': true,
      'dhuhr': true,
      'asr': false,
      'maghrib': false,
      'isha': false,
    },
    'isToday': true,
  },
];

List<Map<String, dynamic>> trendJson() => [
  {
    'periodStart': '2026-10-05',
    'periodEnd': '2026-10-11',
    'label': '5 Oct',
    'prayersLogged': 30,
    'points': 160,
    'activeDays': 6,
    'perfectDays': 2,
    'completionPercent': 85.7,
    'isCurrent': false,
  },
  {
    'periodStart': '2026-10-12',
    'periodEnd': '2026-10-18',
    'label': '12 Oct',
    'prayersLogged': 20,
    'points': 100,
    'activeDays': 5,
    'perfectDays': 0,
    'completionPercent': 57.1,
    'isCurrent': false,
  },
  {
    'periodStart': '2026-10-19',
    'periodEnd': '2026-10-25',
    'label': '19 Oct',
    'prayersLogged': 2,
    'points': 15,
    'activeDays': 1,
    'perfectDays': 0,
    'completionPercent': null,
    'isCurrent': true,
  },
];

Map<String, dynamic> overviewJson() => {
  'memberCount': 8,
  'totals': {
    'prayersLogged': 400,
    'points': 2100,
    'perfectMemberDays': 14,
    'membersActiveToday': 6,
  },
  'averageParticipationPercent': 74.5,
  'daily': [
    {
      'date': '2026-10-18',
      'prayersLogged': 30,
      'points': 150,
      'membersQualified': 6,
      'membersTotal': 8,
      'participationPercent': 75.0,
      'isToday': false,
    },
    {
      'date': '2026-10-19',
      'prayersLogged': 12,
      'points': 60,
      'membersQualified': 3,
      'membersTotal': 8,
      'participationPercent': 37.5,
      'isToday': true,
    },
  ],
};

List<Map<String, dynamic>> membersJson() => [
  {
    'userId': 'u1',
    'name': 'Alee',
    'role': 'admin',
    'prayersLogged': 90,
    'points': 500,
    'activeDays': 20,
    'perfectDays': 8,
    'completionPercent': 80.0,
    'currentStreak': 4,
  },
  {
    'userId': 'u2',
    'name': 'Sara',
    'role': 'member',
    'prayersLogged': 80,
    'points': 450,
    'activeDays': 25,
    'perfectDays': 6,
    'completionPercent': 90.0,
    'currentStreak': 9,
  },
  {
    'userId': 'u3',
    'name': 'Newbie',
    'role': 'member',
    'prayersLogged': 1,
    'points': 5,
    'activeDays': 1,
    'perfectDays': 0,
    'completionPercent': null,
    'currentStreak': 0,
  },
];

Map<String, dynamic> memberDetailJson() => {
  'member': {
    'userId': 'u2',
    'name': 'Sara',
    'role': 'member',
    'joinedAt': '2026-09-01T08:00:00.000Z',
  },
  'range': rangeJson,
  'totals': totalsJson,
  'completion': completionJson,
  'daily': dailyJson(),
  'perPrayer': [
    {
      'prayer': 'fajr',
      'count': 20,
      'percentOfCompletedDays': 71.4,
      'points': 200,
    },
  ],
};

Map<String, dynamic> attentionJson() => {
  'asOf': '2026-10-19',
  'inactiveDaysThreshold': 3,
  'members': [
    {
      'userId': 'u3',
      'name': 'Newbie',
      'flags': ['never_logged'],
      'lastLoggedDate': null,
      'daysSinceLastLog': null,
      'completionLast7': null,
      'completionPrev7': null,
    },
    {
      'userId': 'u4',
      'name': 'Quiet',
      'flags': ['inactive', 'declining', 'future_flag'],
      'lastLoggedDate': '2026-10-10',
      'daysSinceLastLog': 9,
      'completionLast7': 20.0,
      'completionPrev7': 70.0,
    },
    {
      'userId': 'u5',
      'name': 'Mystery',
      'flags': ['future_flag'],
      'lastLoggedDate': '2026-10-18',
      'daysSinceLastLog': 1,
      'completionLast7': 90.0,
      'completionPrev7': 90.0,
    },
  ],
};

// ── Entities, for tests that do not go through JSON ──

GroupMemberStat memberStat(
  String id, {
  String? name,
  int points = 0,
  int prayers = 0,
  int activeDays = 0,
  double? completion,
  int streak = 0,
  GroupRole role = GroupRole.member,
}) => GroupMemberStat(
  userId: id,
  name: name ?? id,
  role: role,
  prayersLogged: prayers,
  points: points,
  activeDays: activeDays,
  perfectDays: 0,
  completionPercent: completion,
  currentStreak: streak,
);

const offlineStats = Error<Never>(NetworkFailure());

/// A scriptable [StatisticsRepository]: set the results, read the calls.
class FakeStatsRepo implements StatisticsRepository {
  Result<PersonalSummary>? summary;
  Result<List<DailyStat>>? daily;
  Result<List<TrendPoint>>? trend;
  Result<GroupOverview>? overview;
  Result<List<GroupMemberStat>>? members;
  Result<MemberStatsDetail>? detail;
  Result<AttentionReport>? attentionResult;

  final calls = <String>[];
  final froms = <String?>[];
  final granularities = <TrendGranularity>[];

  FakeStatsRepo({bool seeded = true}) {
    if (!seeded) return;
    summary = Success(
      PersonalSummary(
        range: const StatsRange(from: '2026-09-20', to: '2026-10-19'),
        totals: const PeriodTotals(
          prayersLogged: 120,
          points: 640,
          activeDays: 25,
          perfectDays: 10,
        ),
        completion: const Completion(
          percent: 82.5,
          loggedPrayers: 115,
          possiblePrayers: 140,
          completedDays: 28,
        ),
        perPrayer: const [
          PrayerStat(
            prayer: PrayerName.fajr,
            count: 20,
            percentOfCompletedDays: 71.4,
            points: 200,
            currentStreak: 12,
            bestStreak: 30,
          ),
          PrayerStat(
            prayer: PrayerName.dhuhr,
            count: 27,
            percentOfCompletedDays: 96.4,
            points: 135,
            currentStreak: 3,
            bestStreak: 9,
          ),
        ],
        strongest: PrayerName.dhuhr,
        weakest: PrayerName.fajr,
      ),
    );
    daily = Success([
      for (var i = 0; i < 14; i++)
        DailyStat(
          date: '2026-10-${(6 + i).toString().padLeft(2, '0')}',
          prayersLogged: i % 6,
          points: (i % 6) * 5,
          prayers: {
            for (final (j, p) in PrayerName.values.indexed) p: j < i % 6,
          },
          isToday: i == 13,
        ),
    ]);
    trend = const Success([
      TrendPoint(
        periodStart: '2026-10-05',
        periodEnd: '2026-10-11',
        label: '5 Oct',
        prayersLogged: 30,
        points: 160,
        activeDays: 6,
        perfectDays: 2,
        completionPercent: 85.7,
        isCurrent: false,
      ),
      TrendPoint(
        periodStart: '2026-10-12',
        periodEnd: '2026-10-18',
        label: '12 Oct',
        prayersLogged: 2,
        points: 15,
        activeDays: 1,
        perfectDays: 0,
        completionPercent: null,
        isCurrent: true,
      ),
    ]);
    overview = const Success(
      GroupOverview(
        memberCount: 8,
        totals: GroupTotals(
          prayersLogged: 400,
          points: 2100,
          perfectMemberDays: 14,
          membersActiveToday: 6,
        ),
        averageParticipationPercent: 74.5,
        daily: [
          GroupDay(
            date: '2026-10-18',
            prayersLogged: 30,
            points: 150,
            membersQualified: 6,
            membersTotal: 8,
            participationPercent: 75,
            isToday: false,
          ),
          GroupDay(
            date: '2026-10-19',
            prayersLogged: 12,
            points: 60,
            membersQualified: 3,
            membersTotal: 8,
            participationPercent: 37.5,
            isToday: true,
          ),
        ],
      ),
    );
    members = Success([
      memberStat(
        'u1',
        name: 'Alee',
        points: 500,
        prayers: 90,
        activeDays: 20,
        completion: 80,
        streak: 4,
        role: GroupRole.admin,
      ),
      memberStat(
        'u2',
        name: 'Sara',
        points: 450,
        prayers: 80,
        activeDays: 25,
        completion: 90,
        streak: 9,
      ),
      memberStat('u3', name: 'Newbie', points: 5, prayers: 1, activeDays: 1),
    ]);
    detail = Success(
      MemberStatsDetail(
        member: MemberIdentity(
          userId: 'u2',
          name: 'Sara',
          role: GroupRole.member,
          joinedAt: DateTime.utc(2026, 9, 1),
        ),
        range: const StatsRange(from: '2026-09-20', to: '2026-10-19'),
        totals: const PeriodTotals(
          prayersLogged: 80,
          points: 450,
          activeDays: 25,
          perfectDays: 6,
        ),
        completion: const Completion(
          percent: 90,
          loggedPrayers: 80,
          possiblePrayers: 90,
          completedDays: 18,
        ),
        daily: [
          for (var i = 0; i < 7; i++)
            DailyStat(
              date: '2026-10-${(13 + i).toString().padLeft(2, '0')}',
              prayersLogged: i % 6,
              points: 0,
              prayers: {
                for (final (j, p) in PrayerName.values.indexed) p: j < i % 6,
              },
              isToday: i == 6,
            ),
        ],
        perPrayer: const [
          PrayerStat(
            prayer: PrayerName.fajr,
            count: 20,
            percentOfCompletedDays: 71.4,
            points: 200,
          ),
        ],
      ),
    );
    attentionResult = const Success(
      AttentionReport(
        asOf: '2026-10-19',
        inactiveDaysThreshold: 3,
        members: [
          AttentionMember(
            userId: 'u3',
            name: 'Newbie',
            flags: [AttentionFlag.neverLogged],
            lastLoggedDate: null,
            daysSinceLastLog: null,
            completionLast7: null,
            completionPrev7: null,
          ),
          AttentionMember(
            userId: 'u4',
            name: 'Quiet',
            flags: [AttentionFlag.inactive, AttentionFlag.declining],
            lastLoggedDate: '2026-10-10',
            daysSinceLastLog: 9,
            completionLast7: 20,
            completionPrev7: 70,
          ),
        ],
      ),
    );
  }

  Result<T> _r<T>(Result<T>? r, String call, [String? from]) {
    calls.add(call);
    froms.add(from);
    return r ?? const Error(UnexpectedFailure());
  }

  @override
  Future<Result<PersonalSummary>> mySummary({String? from}) async =>
      _r(summary, 'mySummary', from);

  @override
  Future<Result<List<DailyStat>>> myDaily({String? from}) async =>
      _r(daily, 'myDaily', from);

  @override
  Future<Result<List<TrendPoint>>> myTrend(
    TrendGranularity granularity, {
    int? periods,
  }) async {
    granularities.add(granularity);
    return _r(trend, 'myTrend');
  }

  @override
  Future<Result<GroupOverview>> groupOverview(
    String groupId, {
    String? from,
  }) async => _r(overview, 'groupOverview', from);

  @override
  Future<Result<List<GroupMemberStat>>> groupMembers(
    String groupId, {
    String? from,
  }) async => _r(members, 'groupMembers', from);

  @override
  Future<Result<MemberStatsDetail>> memberDetail(
    String groupId,
    String userId, {
    String? from,
  }) async => _r(detail, 'memberDetail:$userId', from);

  @override
  Future<Result<AttentionReport>> attention(
    String groupId, {
    int? inactiveDays,
  }) async => _r(attentionResult, 'attention');
}
