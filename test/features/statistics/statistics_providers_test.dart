import 'package:deen_companion/core/error/failures.dart';
import 'package:deen_companion/features/auth/domain/entities/auth_session.dart';
import 'package:deen_companion/features/auth/presentation/providers/auth_session_provider.dart';
import 'package:deen_companion/features/statistics/domain/entities/stats_common.dart';
import 'package:deen_companion/features/statistics/presentation/providers/statistics_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '_stats_support.dart';

class _SignedIn extends AuthSessionNotifier {
  @override
  AuthSession build() =>
      const AuthSession(userId: 'u1', email: 'a@b.c', name: 'Alee');
  void switchTo(String id) =>
      state = AuthSession(userId: id, email: '$id@b.c', name: id);
}

void main() {
  late FakeStatsRepo repo;
  setUp(() => repo = FakeStatsRepo());

  ProviderContainer make() {
    final c = ProviderContainer(
      overrides: [
        statisticsRepositoryProvider.overrideWithValue(repo),
        statsClockProvider.overrideWithValue(() => DateTime(2026, 10, 19)),
        authSessionProvider.overrideWith(_SignedIn.new),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  group('reads', () {
    test('every provider reads from the repository', () async {
      final c = make();
      expect((await c.read(groupOverviewProvider('g1').future)).memberCount, 8);
      expect(await c.read(groupMemberStatsProvider('g1').future), hasLength(3));
      expect(
        (await c.read(
          memberStatsDetailProvider((groupId: 'g1', userId: 'u2')).future,
        )).member.name,
        'Sara',
      );
      expect(
        (await c.read(attentionProvider('g1').future)).members,
        hasLength(2),
      );
      expect((await c.read(mySummaryProvider.future)).totals.points, 640);
      expect(await c.read(myDailyProvider.future), hasLength(14));
    });

    test('a failure surfaces as the Failure', () async {
      repo.overview = offlineStats;
      repo.summary = offlineStats;
      final c = make();
      await expectLater(
        c.read(groupOverviewProvider('g1').future),
        throwsA(isA<NetworkFailure>()),
      );
      await expectLater(
        c.read(mySummaryProvider.future),
        throwsA(isA<NetworkFailure>()),
      );
    });
  });

  group('the period', () {
    test('30 days (the default) sends no date', () async {
      final c = make();
      await c.read(groupOverviewProvider('g1').future);
      expect(repo.froms.single, isNull);
    });

    test('7 days sends the first day, and refetches by itself', () async {
      final c = make();
      final sub = c.listen(groupOverviewProvider('g1'), (_, _) {});
      await c.read(groupOverviewProvider('g1').future);

      c.read(statsPeriodProvider.notifier).state = StatsPeriod.week;
      await c.read(groupOverviewProvider('g1').future);
      expect(repo.froms, [null, '2026-10-13']);
      sub.close();
    });

    test('one choice drives every statistic that takes a range', () async {
      final c = make();
      c.read(statsPeriodProvider.notifier).state = StatsPeriod.quarter;
      await c.read(groupMemberStatsProvider('g1').future);
      await c.read(mySummaryProvider.future);
      await c.read(myDailyProvider.future);
      await c.read(
        memberStatsDetailProvider((groupId: 'g1', userId: 'u2')).future,
      );
      expect(repo.froms, everyElement('2026-07-22'));
      expect(repo.froms, hasLength(4));
    });

    test('attention does not take the range', () async {
      final c = make();
      c.read(statsPeriodProvider.notifier).state = StatsPeriod.week;
      await c.read(attentionProvider('g1').future);
      expect(repo.froms, [null]);
    });
  });

  group('refreshing', () {
    test(
      'after a prayer is logged the next read asks the server again',
      () async {
        final c = make();
        final subs = [
          c.listen(groupOverviewProvider('g1'), (_, _) {}),
          c.listen(mySummaryProvider, (_, _) {}),
          c.listen(attentionProvider('g1'), (_, _) {}),
        ];
        await c.read(groupOverviewProvider('g1').future);
        await c.read(mySummaryProvider.future);
        await c.read(attentionProvider('g1').future);
        expect(repo.calls, hasLength(3));

        c.read(refreshStatisticsProvider)();
        await c.read(groupOverviewProvider('g1').future);
        await c.read(mySummaryProvider.future);
        await c.read(attentionProvider('g1').future);
        expect(
          repo.calls,
          hasLength(6),
          reason: 'only what was open refetches',
        );
        for (final s in subs) {
          s.close();
        }
      },
    );

    test('another account signing in drops the kept numbers', () async {
      final c = make();
      final sub = c.listen(mySummaryProvider, (_, _) {});
      await c.read(mySummaryProvider.future);
      sub.close();
      await Future<void>.delayed(Duration.zero);

      (c.read(authSessionProvider.notifier) as _SignedIn).switchTo('u2');
      await Future<void>.delayed(Duration.zero);
      await c.read(mySummaryProvider.future);
      expect(
        repo.calls.where((x) => x == 'mySummary'),
        hasLength(2),
        reason: 'u2 must not see u1\'s numbers',
      );
    });
  });
}
