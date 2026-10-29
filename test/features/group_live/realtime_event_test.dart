import 'package:deen_companion/features/prayer_logs/domain/prayer_log.dart';
import 'package:deen_companion/features/group_live/domain/group_summary.dart';
import 'package:deen_companion/features/group_live/domain/realtime_event.dart';
import 'package:deen_companion/features/groups/domain/entities/group.dart';
import 'package:deen_companion/features/prayer_times/domain/entities/prayer_times.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> logged() => {
  'eventId': 'e1',
  'emittedAt': '2026-10-22T04:31:07.412Z',
  'groupId': 'g1',
  'log': {
    'id': 'l1',
    'userId': 'u1',
    'prayer': 'fajr',
    'date': '2026-10-22',
    'points': 10,
    'loggedAt': '2026-10-22T04:31:06.980Z',
    'snapUrl': null,
    'hasSnap': true,
  },
  'member': {
    'userId': 'u1',
    'todayCount': 1,
    'points': 135,
    'currentStreak': 4,
    'bestStreak': 9,
  },
  'group': {
    'memberCount': 12,
    'goalMetCount': 5,
    'topCurrentStreak': 21,
    'bestStreak': 40,
  },
};

void main() {
  group('parseRealtimeEvent', () {
    test('prayer.logged keeps the date as a plain string and times as UTC', () {
      final e = parseRealtimeEvent('prayer.logged', logged());
      expect(e, isA<PrayerLoggedEvent>());
      final p = e! as PrayerLoggedEvent;
      expect(p.log.date, '2026-10-22');
      expect(p.log.prayer, PrayerName.fajr);
      expect(p.log.hasSnap, isTrue);
      expect(p.log.toPrayerLog().snapUrl, isNull);
      expect(p.log.toPrayerLog().snapState(DateTime.now()), SnapState.unopened);
      expect(p.emittedAt, DateTime.utc(2026, 10, 22, 4, 31, 7, 412));
      expect(p.emittedAt.isUtc, isTrue);
      expect(p.group.goalMetCount, 5);
      expect(p.member.points, 135);
    });

    test('prayer.deleted carries ids only', () {
      final e = parseRealtimeEvent('prayer.deleted', {
        'eventId': 'e2',
        'emittedAt': '2026-10-22T04:35:40.101Z',
        'groupId': 'g1',
        'logId': 'l1',
        'userId': 'u1',
        'member': (logged()['member'] as Map),
        'group': (logged()['group'] as Map),
      });
      expect((e! as PrayerDeletedEvent).logId, 'l1');
    });

    test('group.changed maps every documented reason', () {
      const reasons = {
        'member_joined': GroupChangeReason.memberJoined,
        'member_left': GroupChangeReason.memberLeft,
        'member_removed': GroupChangeReason.memberRemoved,
        'role_changed': GroupChangeReason.roleChanged,
        'rule_changed': GroupChangeReason.ruleChanged,
        'group_updated': GroupChangeReason.groupUpdated,
        'group_deleted': GroupChangeReason.groupDeleted,
        'something_new': GroupChangeReason.unknown,
      };
      for (final r in reasons.entries) {
        final e = parseRealtimeEvent('group.changed', {
          'eventId': 'e3',
          'emittedAt': '2026-10-22T05:02:11.730Z',
          'groupId': 'g1',
          'reason': r.key,
        });
        expect((e! as GroupChangedEvent).reason, r.value, reason: r.key);
      }
    });

    test('a malformed payload is dropped, never half applied', () {
      expect(parseRealtimeEvent('prayer.logged', 'nope'), isNull);
      expect(parseRealtimeEvent('prayer.logged', {'eventId': 'x'}), isNull);
      expect(
        parseRealtimeEvent('prayer.logged', {
          ...logged(),
          'emittedAt': 'not a date',
        }),
        isNull,
      );
      final badPrayer = logged();
      (badPrayer['log'] as Map)['prayer'] = 'sunrise';
      expect(parseRealtimeEvent('prayer.logged', badPrayer), isNull);
      expect(parseRealtimeEvent('who.knows', logged()), isNull);
    });
  });

  group('GroupSummary', () {
    LiveMember m(String id, int points, {DateTime? joined, int count = 0}) =>
        LiveMember(
          userId: id,
          name: id,
          role: GroupRole.member,
          todayCount: count,
          todayRequired: 2,
          todayQualified: count >= 2,
          points: points,
          currentStreak: 1,
          bestStreak: 2,
          joinedAt: joined,
        );

    test('leaderboard: points descending, then who joined first', () {
      final sorted = sortLeaderboard([
        m('late', 50, joined: DateTime.utc(2026, 5)),
        m('top', 90, joined: DateTime.utc(2026, 9)),
        m('early', 50, joined: DateTime.utc(2026, 1)),
        m('unknown', 50),
      ]);
      expect(
        [for (final x in sorted) x.userId],
        ['top', 'early', 'late', 'unknown'],
      );
    });

    test(
      'applying an event updates one row, re-sorts and keeps minPrayers',
      () {
        final summary = GroupSummary(
          group: const GroupNumbers(
            memberCount: 2,
            goalMetCount: 0,
            topCurrentStreak: 1,
            bestStreak: 2,
            minPrayers: 2,
          ),
          members: [m('a', 20), m('b', 10)],
        );
        final next = summary.applying(
          group: const GroupNumbers(
            memberCount: 2,
            goalMetCount: 1,
            topCurrentStreak: 5,
            bestStreak: 5,
          ),
          member: const MemberSnapshot(
            userId: 'b',
            todayCount: 2,
            points: 30,
            currentStreak: 5,
            bestStreak: 5,
          ),
        );
        expect([for (final x in next.members) x.userId], ['b', 'a']);
        expect(next.members.first.todayQualified, isTrue);
        expect(next.group.goalMetCount, 1);
        expect(next.group.minPrayers, 2);
        expect(next.toBoard().entries.first.userId, 'b');
      },
    );
  });
}
