import 'dart:async';

import 'package:deen_companion/core/error/exceptions.dart';
import 'package:deen_companion/features/auth/domain/entities/auth_session.dart';
import 'package:deen_companion/features/auth/presentation/providers/auth_session_provider.dart';
import 'package:deen_companion/features/group_live/data/group_summary_remote_datasource.dart';
import 'package:deen_companion/features/group_live/domain/group_summary.dart';
import 'package:deen_companion/features/group_live/domain/realtime_event.dart';
import 'package:deen_companion/features/group_live/presentation/providers/group_live_store.dart';
import 'package:deen_companion/features/group_live/presentation/providers/realtime_providers.dart';
import 'package:deen_companion/features/groups/domain/entities/group.dart';
import 'package:deen_companion/features/groups/presentation/providers/groups_providers.dart';
import 'package:deen_companion/features/prayer_logs/domain/group_member_prayers.dart';
import 'package:deen_companion/features/prayer_logs/domain/prayer_log.dart';
import 'package:deen_companion/features/prayer_times/domain/entities/prayer_times.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '_live_support.dart';

class _Session extends AuthSessionNotifier {
  @override
  AuthSession build() => const AuthSession(userId: 'me', email: 'm@b.c');
}

class _Groups extends MyGroupsNotifier {
  @override
  Future<List<Group>> build() async => const [
    Group(id: 'g1', name: 'One'),
    Group(id: 'g2', name: 'Two'),
  ];
}

LiveMember _m(String id, int points, {int count = 0}) => LiveMember(
  userId: id,
  name: id,
  role: GroupRole.member,
  todayCount: count,
  todayRequired: 2,
  todayQualified: count >= 2,
  points: points,
  currentStreak: 1,
  bestStreak: 1,
  joinedAt: DateTime.utc(2026, 1),
);

const _numbers = GroupNumbers(
  memberCount: 2,
  goalMetCount: 0,
  topCurrentStreak: 1,
  bestStreak: 1,
  minPrayers: 2,
);

final _t0 = DateTime.utc(2026, 10, 22, 10, 0, 0);

SummaryFresh _fresh({DateTime? at, List<LiveMember>? members}) => SummaryFresh(
  GroupSummary(group: _numbers, members: members ?? [_m('a', 20), _m('b', 10)]),
  '"v1"',
  at ?? _t0,
);

PrayerLoggedEvent _logged(
  String id, {
  required DateTime at,
  String logId = 'l1',
  String user = 'b',
  int points = 30,
  String date = '2026-10-22',
  PrayerName prayer = PrayerName.fajr,
  bool hasSnap = false,
}) => PrayerLoggedEvent(
  eventId: id,
  emittedAt: at,
  groupId: 'g1',
  log: LiveLog(
    id: logId,
    userId: user,
    prayer: prayer,
    date: date,
    points: 10,
    loggedAt: at,
    hasSnap: hasSnap,
  ),
  member: MemberSnapshot(
    userId: user,
    todayCount: 2,
    points: points,
    currentStreak: 3,
    bestStreak: 3,
  ),
  group: const GroupNumbers(
    memberCount: 2,
    goalMetCount: 1,
    topCurrentStreak: 3,
    bestStreak: 3,
  ),
);

({ProviderContainer c, FakeSummaryRemote remote}) _setup() {
  final remote = FakeSummaryRemote()..handler = (_, _) async => _fresh();
  final c = ProviderContainer(
    overrides: [
      authSessionProvider.overrideWith(_Session.new),
      myGroupsProvider.overrideWith(_Groups.new),
      realtimeServiceProvider.overrideWithValue(null),
      groupSummaryRemoteDataSourceProvider.overrideWithValue(remote),
    ],
  );
  addTearDown(c.dispose);
  return (c: c, remote: remote);
}

Future<GroupLiveNotifier> _open(ProviderContainer c) async {
  c.listen(groupLiveProvider('g1'), (_, _) {});
  await pumpEventQueue();
  return c.read(groupLiveProvider('g1').notifier);
}

void main() {
  test(
    'the first summary fills the numbers and sets lastAppliedAt to Date',
    () async {
      final s = _setup();
      await _open(s.c);
      final state = s.c.read(groupLiveProvider('g1'));
      expect(state.summary!.members.map((m) => m.userId), ['a', 'b']);
      expect(state.lastAppliedAt, _t0);
      expect(state.etag, '"v1"');
    },
  );

  test('refetch sends If-None-Match and a 304 keeps what is held', () async {
    final s = _setup();
    final n = await _open(s.c);
    s.remote.handler = (_, etag) async =>
        SummaryNotModified(_t0.add(const Duration(seconds: 5)));
    await n.refresh();
    expect(s.remote.calls.last.etag, '"v1"');
    final state = s.c.read(groupLiveProvider('g1'));
    expect(state.summary!.members, hasLength(2));
    expect(state.lastAppliedAt, _t0.add(const Duration(seconds: 5)));
  });

  test(
    'prayer.logged: numbers, order and the log row; the id is not added twice',
    () async {
      final s = _setup();
      final n = await _open(s.c);
      n.apply(_logged('e1', at: _t0.add(const Duration(seconds: 2))));
      n.apply(_logged('e1b', at: _t0.add(const Duration(seconds: 3))));
      final state = s.c.read(groupLiveProvider('g1'));
      // b overtakes a on points.
      expect(state.summary!.members.first.userId, 'b');
      expect(state.summary!.group.goalMetCount, 1);
      expect(state.addedLogs.keys, ['l1']);
      expect(state.lastAppliedAt, _t0.add(const Duration(seconds: 3)));
    },
  );

  test(
    'the same log again with a snap is an update: one row, now with the snap',
    () async {
      final s = _setup();
      final n = await _open(s.c);
      n.apply(_logged('e1', at: _t0.add(const Duration(seconds: 2))));
      n.apply(
        _logged('e2', at: _t0.add(const Duration(seconds: 3)), hasSnap: true),
      );
      final state = s.c.read(groupLiveProvider('g1'));
      expect(state.addedLogs.keys, ['l1']);
      expect(state.addedLogs['l1']!.hasSnap, isTrue);
      // The numbers are the server's and unchanged: nothing was counted twice.
      expect(state.summary!.group.goalMetCount, 1);
    },
  );

  test('prayer.deleted removes the log and applies the numbers', () async {
    final s = _setup();
    final n = await _open(s.c);
    n.apply(_logged('e1', at: _t0.add(const Duration(seconds: 2))));
    n.apply(
      PrayerDeletedEvent(
        eventId: 'e2',
        emittedAt: _t0.add(const Duration(seconds: 4)),
        groupId: 'g1',
        logId: 'l1',
        userId: 'b',
        member: const MemberSnapshot(
          userId: 'b',
          todayCount: 0,
          points: 10,
          currentStreak: 1,
          bestStreak: 3,
        ),
        group: _numbers,
      ),
    );
    final state = s.c.read(groupLiveProvider('g1'));
    expect(state.addedLogs, isEmpty);
    expect(state.removedLogIds, {'l1'});
    expect(state.summary!.member('b')!.points, 10);
  });

  test(
    'an event older than lastAppliedAt is ignored (compared as instants)',
    () async {
      final s = _setup();
      final n = await _open(s.c);
      // Older than the summary's Date: describes a state already passed.
      n.apply(_logged('old', at: _t0.subtract(const Duration(seconds: 1))));
      final state = s.c.read(groupLiveProvider('g1'));
      expect(state.addedLogs, isEmpty);
      expect(state.summary!.member('b')!.points, 10);
      expect(state.lastAppliedAt, _t0);
      // Equal is not older: it applies.
      n.apply(_logged('same', at: _t0));
      expect(s.c.read(groupLiveProvider('g1')).addedLogs, isNotEmpty);
    },
  );

  test('an event for a member with no row asks for a fresh summary', () async {
    final s = _setup();
    final n = await _open(s.c);
    final before = s.remote.calls.length;
    n.apply(
      _logged('new', at: _t0.add(const Duration(seconds: 2)), user: 'zed'),
    );
    await pumpEventQueue();
    expect(s.remote.calls.length, before + 1);
  });

  test('group.changed refetches the summary, group_updated does not', () async {
    final s = _setup();
    final n = await _open(s.c);
    GroupChangedEvent changed(GroupChangeReason r, int sec) =>
        GroupChangedEvent(
          eventId: 'c$sec',
          emittedAt: _t0.add(Duration(seconds: sec)),
          groupId: 'g1',
          reason: r,
        );
    var calls = s.remote.calls.length;
    for (final (i, r) in [
      GroupChangeReason.memberJoined,
      GroupChangeReason.memberLeft,
      GroupChangeReason.memberRemoved,
      GroupChangeReason.roleChanged,
      GroupChangeReason.ruleChanged,
    ].indexed) {
      n.apply(changed(r, i + 1));
      await pumpEventQueue();
      expect(s.remote.calls.length, ++calls, reason: '$r');
    }
    n.apply(changed(GroupChangeReason.groupUpdated, 9));
    await pumpEventQueue();
    expect(s.remote.calls.length, calls);
  });

  test(
    'group_deleted marks the group gone and drops it from the list',
    () async {
      final s = _setup();
      await s.c.read(myGroupsProvider.future);
      final n = await _open(s.c);
      n.apply(
        GroupChangedEvent(
          eventId: 'd',
          emittedAt: _t0.add(const Duration(seconds: 1)),
          groupId: 'g1',
          reason: GroupChangeReason.groupDeleted,
        ),
      );
      expect(s.c.read(groupLiveProvider('g1')).gone, GroupGone.deleted);
      expect(s.c.read(myGroupsProvider).value!.map((g) => g.id), ['g2']);
    },
  );

  test(
    'a 403 on the summary means removed: gone, and dropped from the list',
    () async {
      final s = _setup();
      await s.c.read(myGroupsProvider.future);
      s.remote.handler = (_, _) async => throw const ServerException(null, 403);
      await _open(s.c);
      expect(s.c.read(groupLiveProvider('g1')).gone, GroupGone.removed);
      expect(s.c.read(myGroupsProvider).value!.map((g) => g.id), ['g2']);
    },
  );

  test(
    'an event newer than a summary still in flight triggers another fetch',
    () async {
      final s = _setup();
      final n = await _open(s.c);
      final first = Completer<SummaryResponse>();
      var calls = 0;
      s.remote.handler = (_, _) {
        calls++;
        return calls == 1
            ? first.future
            : Future.value(_fresh(at: _t0.add(const Duration(seconds: 10))));
      };
      final pending = n.refresh();
      await pumpEventQueue();
      // Applied while the request is on its way, later than the answer's Date.
      n.apply(_logged('e', at: _t0.add(const Duration(seconds: 8))));
      first.complete(_fresh(at: _t0.add(const Duration(seconds: 5))));
      await pending;
      expect(calls, 2);
    },
  );

  test('a summary failure keeps the numbers already held', () async {
    final s = _setup();
    final n = await _open(s.c);
    s.remote.handler = (_, _) async => throw const NetworkException();
    await n.refresh();
    final state = s.c.read(groupLiveProvider('g1'));
    expect(state.summary, isNotNull);
    expect(state.error, isNotNull);
    expect(state.gone, isNull);
  });

  group('overlayFeed', () {
    PrayerLog log(String id, PrayerName p, {String date = '2026-10-22'}) =>
        PrayerLog(
          id: id,
          prayer: p,
          date: date,
          status: PrayerLogStatus.onTime,
          points: 10,
          snapUrl: null,
          windowStartsAt: _t0,
          windowEndsAt: _t0,
          loggedAt: _t0,
        );
    GroupMemberPrayers member(String id, List<PrayerLog> logs) =>
        GroupMemberPrayers(
          userId: id,
          name: id,
          role: GroupRole.member,
          logs: logs,
        );
    LiveLog live(
      String id,
      String user,
      PrayerName p, {
      String date = '2026-10-22',
    }) => LiveLog(
      id: id,
      userId: user,
      prayer: p,
      date: date,
      points: 10,
      loggedAt: _t0,
    );

    test('inserts a live log on its day, once, in prayer order', () {
      final out = overlayFeed(
        [
          member('a', [log('x', PrayerName.asr)]),
        ],
        added: {'l': live('l', 'a', PrayerName.fajr)},
        removed: const {},
        today: '2026-10-22',
      );
      expect(out.single.logs.map((l) => l.id), ['l', 'x']);
    });

    test('a log already in the feed is not doubled, by id or by prayer', () {
      final out = overlayFeed(
        [
          member('a', [log('x', PrayerName.fajr)]),
        ],
        added: {
          'x': live('x', 'a', PrayerName.fajr),
          'y': live('y', 'a', PrayerName.fajr),
        },
        removed: const {},
        today: '2026-10-22',
      );
      expect(out.single.logs.map((l) => l.id), ['x']);
    });

    test('a live update flips a log already in the feed to "has a snap"', () {
      final out = overlayFeed(
        [
          member('a', [log('x', PrayerName.fajr)]),
        ],
        added: {
          'x': LiveLog(
            id: 'x',
            userId: 'a',
            prayer: PrayerName.fajr,
            date: '2026-10-22',
            points: 10,
            loggedAt: _t0,
            hasSnap: true,
          ),
        },
        removed: const {},
        today: '2026-10-22',
      );
      expect(out.single.logs.single.hasSnap, isTrue);
    });

    test('a log from another day has no row in today\'s feed', () {
      final out = overlayFeed(
        [member('a', const [])],
        added: {'l': live('l', 'a', PrayerName.fajr, date: '2026-10-21')},
        removed: const {},
        today: '2026-10-22',
      );
      expect(out.single.logs, isEmpty);
    });

    test('removed ids disappear', () {
      final out = overlayFeed(
        [
          member('a', [log('x', PrayerName.fajr)]),
        ],
        added: const {},
        removed: {'x'},
        today: '2026-10-22',
      );
      expect(out.single.logs, isEmpty);
    });
  });
}
