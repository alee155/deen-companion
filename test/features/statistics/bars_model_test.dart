import 'package:deen_companion/features/prayer_times/domain/entities/prayer_times.dart';
import 'package:deen_companion/features/statistics/domain/bars_model.dart';
import 'package:deen_companion/features/statistics/domain/entities/group_stats.dart';
import 'package:deen_companion/features/statistics/domain/entities/stats_common.dart';
import 'package:flutter_test/flutter_test.dart';

GroupOverview overview(List<GroupDay> days, {double? avg = 70}) =>
    GroupOverview(
      memberCount: 8,
      totals: const GroupTotals(
        prayersLogged: 0,
        points: 0,
        perfectMemberDays: 0,
        membersActiveToday: 0,
      ),
      averageParticipationPercent: avg,
      daily: days,
    );

GroupDay gday(String d, double? pct, int q, int t, {bool today = false}) =>
    GroupDay(
      date: d,
      prayersLogged: 0,
      points: 0,
      membersQualified: q,
      membersTotal: t,
      participationPercent: pct,
      isToday: today,
    );

DailyStat dstat(String d, int n, {bool today = false}) => DailyStat(
  date: d,
  prayersLogged: n,
  points: 0,
  prayers: {for (final p in PrayerName.values) p: false},
  isToday: today,
);

void main() {
  group('BarsModel.group', () {
    final m = BarsModel.group(
      overview([
        gday('2026-10-18', 75, 6, 8),
        gday('2026-10-19', 37.5, 3, 8, today: true),
      ], avg: 61.5),
    );

    test('a bar per day with the participation, and the average', () {
      expect(m.title, 'Group');
      expect(m.days.map((d) => d.percent), [75, 37.5]);
      expect(m.average, 61.5);
    });

    test('says what a bar means in words', () {
      expect(m.days.first.detail, '6 of 8 members reached the goal');
    });

    test('flags today, which is drawn as not over yet', () {
      expect(m.days.map((d) => d.partial), [false, true]);
      expect(m.todayIndex, 1);
    });

    test('a day nobody had joined yet has no data, not 0%', () {
      final b = BarsModel.group(overview([gday('2026-10-01', null, 0, 0)]));
      expect(b.days.single.percent, isNull);
      expect(b.days.single.detail, 'No members yet');
    });
  });

  group('BarsModel.person', () {
    final m = BarsModel.person(
      title: 'Sara',
      average: 83,
      daily: [
        dstat('2026-10-17', 5),
        dstat('2026-10-18', 0),
        dstat('2026-10-19', 2, today: true),
      ],
    );

    test('a bar per day: the share of five prayers', () {
      expect(m.title, 'Sara');
      expect(m.days.map((d) => d.percent), [100, 0, 40]);
      expect(m.average, 83);
    });

    test('no prayers is 0%, which is different from no data', () {
      expect(m.days[1].percent, 0);
    });

    test('says what a bar means in words', () {
      expect(m.days.first.detail, '5 of 5 prayers');
      expect(m.days.last.detail, '2 of 5 prayers');
    });

    test('flags today', () {
      expect(m.todayIndex, 2);
    });
  });

  test('with no day flagged the last one is "today"', () {
    final m = BarsModel.group(
      overview([gday('2026-10-17', 1, 1, 1), gday('2026-10-18', 2, 1, 1)]),
    );
    expect(m.todayIndex, 1);
  });

  test('no days is empty', () {
    final m = BarsModel.person(title: 'x', daily: const []);
    expect(m.isEmpty, isTrue);
    expect(m.todayIndex, 0);
  });

  group('StatsSubject', () {
    test('equal when they mean the same thing', () {
      expect(StatsSubject.group, const GroupSubject());
      expect(StatsSubject.me, const MeSubject());
      expect(const MemberSubject('u2'), const MemberSubject('u2'));
      expect(const MemberSubject('u2'), isNot(const MemberSubject('u3')));
      expect(StatsSubject.group, isNot(StatsSubject.me));
    });
  });
}
