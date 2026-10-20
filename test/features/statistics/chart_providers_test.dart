import 'package:deen_companion/features/auth/domain/entities/auth_session.dart';
import 'package:deen_companion/features/auth/presentation/providers/auth_session_provider.dart';
import 'package:deen_companion/features/statistics/domain/bars_model.dart';
import 'package:deen_companion/features/statistics/domain/entities/stats_common.dart';
import 'package:deen_companion/features/statistics/presentation/providers/chart_providers.dart';
import 'package:deen_companion/features/statistics/presentation/providers/statistics_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '_stats_support.dart';

class _SignedIn extends AuthSessionNotifier {
  @override
  AuthSession build() =>
      const AuthSession(userId: 'u1', email: 'a@b.c', name: 'Alee');
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

  Future<AsyncValue<T>> settled<T>(
    ProviderContainer c,
    ProviderListenable<AsyncValue<T>> p,
  ) async {
    final sub = c.listen(p, (_, _) {});
    addTearDown(sub.close);
    for (var i = 0; i < 20; i++) {
      await Future<void>.delayed(Duration.zero);
      final v = c.read(p);
      if (!v.isLoading) return v;
    }
    fail('never settled');
  }

  group('statsBarsProvider', () {
    test('starts on the group, from the overview alone', () async {
      final c = make();
      expect(c.read(statsSubjectProvider), StatsSubject.group);
      final v = await settled(c, statsBarsProvider('g1'));
      expect(v.requireValue.title, 'Group');
      expect(v.requireValue.days.map((d) => d.percent), [75, 37.5]);
      expect(v.requireValue.average, 74.5);
      expect(repo.calls, ['groupOverview'], reason: 'nothing else is fetched');
    });

    test(
      '"You" shows your days, with your completion as the average',
      () async {
        final c = make();
        c.read(statsSubjectProvider.notifier).state = StatsSubject.me;
        final v = await settled(c, statsBarsProvider('g1'));
        expect(v.requireValue.title, 'You');
        expect(v.requireValue.days, hasLength(14));
        expect(v.requireValue.average, 82.5);
        expect(repo.calls, contains('myDaily'));
        expect(repo.calls, isNot(contains('groupOverview')));
      },
    );

    test('a member is fetched when chosen, and named', () async {
      final c = make();
      c.read(statsSubjectProvider.notifier).state = const MemberSubject('u2');
      final v = await settled(c, statsBarsProvider('g1'));
      expect(v.requireValue.title, 'Sara');
      expect(v.requireValue.average, 90);
      expect(repo.calls, ['memberDetail:u2']);
    });

    test('changing the subject changes the bars', () async {
      final c = make();
      final sub = c.listen(statsBarsProvider('g1'), (_, _) {});
      addTearDown(sub.close);
      await settled(c, statsBarsProvider('g1'));
      c.read(statsSubjectProvider.notifier).state = StatsSubject.me;
      final v = await settled(c, statsBarsProvider('g1'));
      expect(v.requireValue.title, 'You');
    });

    test('a failure is the Failure, for whichever subject', () async {
      repo.overview = offlineStats;
      repo.daily = offlineStats;
      repo.detail = offlineStats;
      final c = make();
      expect((await settled(c, statsBarsProvider('g1'))).hasError, isTrue);
      c.read(statsSubjectProvider.notifier).state = StatsSubject.me;
      expect((await settled(c, statsBarsProvider('g1'))).hasError, isTrue);
      c.read(statsSubjectProvider.notifier).state = const MemberSubject('u2');
      expect((await settled(c, statsBarsProvider('g1'))).hasError, isTrue);
    });

    test('the period changes the range of whoever is shown', () async {
      final c = make();
      final sub = c.listen(statsBarsProvider('g1'), (_, _) {});
      addTearDown(sub.close);
      await settled(c, statsBarsProvider('g1'));
      c.read(statsPeriodProvider.notifier).state = StatsPeriod.week;
      await settled(c, statsBarsProvider('g1'));
      expect(repo.froms, [null, '2026-10-13']);
    });
  });

  group('memberRowsProvider', () {
    test('the admin gets the attention flags merged in', () async {
      final c = make();
      final v = await settled(
        c,
        memberRowsProvider((groupId: 'g1', isAdmin: true)),
      );
      final rows = v.requireValue;
      expect(rows.map((r) => r.stat.userId), ['u1', 'u2', 'u3']);
      expect(
        rows.firstWhere((r) => r.stat.userId == 'u3').attention,
        isNotNull,
      );
      expect(rows.firstWhere((r) => r.stat.userId == 'u2').attention, isNull);
      expect(repo.calls, contains('attention'));
    });

    test('a member never asks for the admin report', () async {
      final c = make();
      final v = await settled(
        c,
        memberRowsProvider((groupId: 'g1', isAdmin: false)),
      );
      expect(v.requireValue.every((r) => r.attention == null), isTrue);
      expect(repo.calls, isNot(contains('attention')));
    });

    test('a failing attention report only means no flags', () async {
      repo.attentionResult = offlineStats;
      final c = make();
      final v = await settled(
        c,
        memberRowsProvider((groupId: 'g1', isAdmin: true)),
      );
      expect(v.hasValue, isTrue);
      expect(v.requireValue.every((r) => r.attention == null), isTrue);
    });

    test('the members failing is an error', () async {
      repo.members = offlineStats;
      final c = make();
      final v = await settled(
        c,
        memberRowsProvider((groupId: 'g1', isAdmin: false)),
      );
      expect(v.hasError, isTrue);
    });
  });
}
