import 'package:deen_companion/core/error/failures.dart';
import 'package:deen_companion/core/usecase/usecase.dart';
import 'package:deen_companion/features/groups/data/datasources/groups_local_datasource.dart';
import 'package:deen_companion/features/groups/data/repositories/groups_repository_impl.dart';
import 'package:deen_companion/features/groups/domain/entities/group.dart';
import 'package:deen_companion/features/groups/domain/entities/group_streak.dart';
import 'package:deen_companion/features/groups/domain/repositories/groups_repository.dart';
import 'package:deen_companion/features/groups/presentation/providers/groups_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _newGroup = NewGroup(
  name: 'Test Circle',
  description: 'desc',
  privacy: GroupPrivacy.private,
  adminApproval: true,
  imagePath: '/tmp/x.png',
);

class ThrowingDataSource extends GroupsLocalDataSource {
  @override
  List<Group> groups() => throw StateError('boom');
  @override
  Group? byId(String id) => throw StateError('boom');
  @override
  UserStreakStats myStats() => throw StateError('boom');
}

class FailingRepo implements GroupsRepository {
  @override
  Future<Result<Group>> createGroup(NewGroup input) async =>
      const Error(UnexpectedFailure());
  @override
  Future<Result<GroupStreakSummary>> getGroupStreak(String groupId) async =>
      const Error(NotFoundFailure());
  @override
  Future<Result<List<Group>>> getMyGroups() async =>
      const Error(UnexpectedFailure());
  @override
  Future<Result<UserStreakStats>> getMyStreakStats() async =>
      const Error(UnexpectedFailure());
}

void main() {
  group('Group entity', () {
    test('isPrivate reflects privacy', () {
      expect(
        const Group(
          id: '1',
          name: 'a',
          description: '',
          privacy: GroupPrivacy.private,
          memberCount: 1,
        ).isPrivate,
        isTrue,
      );
      expect(
        const Group(
          id: '1',
          name: 'a',
          description: '',
          privacy: GroupPrivacy.public,
          memberCount: 1,
        ).isPrivate,
        isFalse,
      );
    });
  });

  group('GroupStreakSummary / MemberActivity / UserStreakStats', () {
    GroupStreakSummary summary(int members, int done) => GroupStreakSummary(
      groupId: 'g',
      groupName: 'G',
      currentStreak: 1,
      longestStreak: 2,
      week: const [],
      memberCount: members,
      completedTodayCount: done,
      members: const [],
    );

    test('todayProgress is a ratio', () {
      expect(summary(8, 6).todayProgress, 0.75);
      expect(summary(8, 6).remainingToday, 2);
    });

    test('todayProgress is 0 (not NaN) for empty group', () {
      expect(summary(0, 0).todayProgress, 0);
    });

    test('initials uses first two words, uppercased', () {
      const m = MemberActivity(
        id: '1',
        name: ' muhammad  ali khan',
        streakDays: 1,
        completedToday: true,
      );
      expect(m.initials, 'MA');
      expect(
        const MemberActivity(
          id: '2',
          name: '',
          streakDays: 0,
          completedToday: false,
        ).initials,
        '',
      );
    });

    test('activeDaysThisWeek counts true flags; empty is all zero', () {
      const s = UserStreakStats(
        currentStreak: 3,
        longestStreak: 5,
        week: [true, false, true, true, false, false, false],
        todayIndex: 3,
      );
      expect(s.activeDaysThisWeek, 3);
      expect(UserStreakStats.empty.activeDaysThisWeek, 0);
      expect(UserStreakStats.empty.week, hasLength(7));
    });
  });

  group('GroupsLocalDataSource', () {
    late GroupsLocalDataSource ds;
    setUp(() => ds = GroupsLocalDataSource());

    test('seed groups are present and list is unmodifiable', () {
      expect(ds.groups(), hasLength(3));
      expect(() => ds.groups().add(ds.groups().first), throwsUnsupportedError);
    });

    test('add inserts at the top as owned group with 1 member', () {
      final g = ds.add(_newGroup);
      expect(ds.groups().first.id, g.id);
      expect(g.isOwner, isTrue);
      expect(g.memberCount, 1);
      expect(g.requiresApproval, isTrue);
      expect(g.privacy, GroupPrivacy.private);
      expect(g.imagePath, '/tmp/x.png');
      expect(ds.groups(), hasLength(4));
    });

    test('byId finds existing and returns null for unknown', () {
      expect(ds.byId('daily-quran-reading')?.name, 'Daily Quran Reading');
      expect(ds.byId('nope'), isNull);
    });

    test('streakFor builds a consistent Mon-first week', () {
      final group = ds.byId('family-quran-circle')!;
      final s = ds.streakFor(group);
      final todayIndex = DateTime.now().weekday - 1;
      expect(s.groupId, group.id);
      expect(s.week, hasLength(7));
      expect(s.week.first.date.weekday, DateTime.monday);
      expect(s.week.where((d) => d.isToday), hasLength(1));
      expect(s.week[todayIndex].isToday, isTrue);
      // Every day before today is complete, today and later are not.
      for (var i = 0; i < 7; i++) {
        expect(s.week[i].completed, i < todayIndex);
      }
      expect(s.currentStreak, todayIndex + 7);
      expect(s.longestStreak, greaterThan(s.currentStreak));
      expect(s.memberCount, group.memberCount);
      expect(s.completedTodayCount, (group.memberCount * 0.75).round());
      expect(s.members, isNotEmpty);
    });

    test('streakFor clamps completed count to member count', () {
      final g = ds.add(_newGroup); // 1 member -> round(0.75) == 1
      final s = ds.streakFor(g);
      expect(s.completedTodayCount, lessThanOrEqualTo(g.memberCount));
    });

    test('myStats matches week shape', () {
      final stats = ds.myStats();
      expect(stats.week, hasLength(7));
      expect(stats.todayIndex, DateTime.now().weekday - 1);
      expect(stats.activeDaysThisWeek, stats.todayIndex);
    });
  });

  group('GroupsRepositoryImpl', () {
    test('getMyGroups returns data', () async {
      final repo = GroupsRepositoryImpl(GroupsLocalDataSource());
      final r = await repo.getMyGroups();
      expect((r as Success<List<Group>>).data, hasLength(3));
    });

    test('createGroup adds to datasource', () async {
      final ds = GroupsLocalDataSource();
      final r = await GroupsRepositoryImpl(ds).createGroup(_newGroup);
      expect(r, isA<Success<Group>>());
      expect(ds.groups().first.name, 'Test Circle');
    });

    test('getGroupStreak: unknown id -> NotFoundFailure', () async {
      final r = await GroupsRepositoryImpl(
        GroupsLocalDataSource(),
      ).getGroupStreak('missing');
      expect((r as Error).failure, isA<NotFoundFailure>());
    });

    test('getGroupStreak: known id -> summary', () async {
      final r = await GroupsRepositoryImpl(
        GroupsLocalDataSource(),
      ).getGroupStreak('daily-quran-reading');
      expect(
        (r as Success<GroupStreakSummary>).data.groupName,
        'Daily Quran Reading',
      );
    });

    test('datasource exceptions map to UnexpectedFailure', () async {
      final repo = GroupsRepositoryImpl(ThrowingDataSource());
      expect(
        ((await repo.getMyGroups()) as Error).failure,
        isA<UnexpectedFailure>(),
      );
      expect(
        ((await repo.getGroupStreak('x')) as Error).failure,
        isA<UnexpectedFailure>(),
      );
      expect(
        ((await repo.getMyStreakStats()) as Error).failure,
        isA<UnexpectedFailure>(),
      );
    });
  });

  group('providers', () {
    ProviderContainer make([GroupsRepository? repo]) {
      final c = ProviderContainer(
        overrides: [
          if (repo != null) groupsRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    test('myGroupsProvider loads and create prepends', () async {
      final c = make();
      expect(await c.read(myGroupsProvider.future), hasLength(3));
      final r = await c.read(myGroupsProvider.notifier).create(_newGroup);
      expect(r, isA<Success<Group>>());
      final groups = c.read(myGroupsProvider).value!;
      expect(groups, hasLength(4));
      expect(groups.first.name, 'Test Circle');
    });

    test('ownedGroupsCountProvider counts owned groups', () async {
      final c = make();
      await c.read(myGroupsProvider.future);
      expect(c.read(ownedGroupsCountProvider), 2);
      await c.read(myGroupsProvider.notifier).create(_newGroup);
      expect(c.read(ownedGroupsCountProvider), 3);
    });

    test('ownedGroupsCountProvider is 0 before data loads', () {
      expect(make().read(ownedGroupsCountProvider), 0);
    });

    test('failure surfaces as AsyncError holding the Failure', () async {
      final c = make(FailingRepo());
      await expectLater(
        c.read(myGroupsProvider.future),
        throwsA(isA<UnexpectedFailure>()),
      );
      await expectLater(
        c.read(groupStreakProvider('x').future),
        throwsA(isA<NotFoundFailure>()),
      );
      await expectLater(
        c.read(myStreakStatsProvider.future),
        throwsA(isA<UnexpectedFailure>()),
      );
    });

    test('groupStreakProvider and myStreakStatsProvider succeed', () async {
      final c = make();
      final s = await c.read(groupStreakProvider('family-quran-circle').future);
      expect(s.groupName, 'Family Quran Circle');
      final stats = await c.read(myStreakStatsProvider.future);
      expect(stats.week, hasLength(7));
    });

    test('data source is shared so created group survives re-reads', () async {
      final c = make();
      await c.read(myGroupsProvider.notifier).create(_newGroup);
      final fresh = await c.read(groupsRepositoryProvider).getMyGroups();
      expect((fresh as Success<List<Group>>).data.first.name, 'Test Circle');
    });
  });
}
