import 'package:deen_companion/core/config/flavor_config.dart';
import 'package:deen_companion/core/usecase/usecase.dart';
import 'package:deen_companion/features/auth/domain/entities/auth_session.dart';
import 'package:deen_companion/features/auth/presentation/providers/auth_session_provider.dart';
import 'package:deen_companion/features/groups/domain/entities/group.dart';
import 'package:deen_companion/features/groups/domain/entities/group_detail.dart';
import 'package:deen_companion/features/groups/presentation/providers/groups_providers.dart';
import 'package:deen_companion/features/statistics/domain/entities/group_stats.dart';
import 'package:deen_companion/features/statistics/presentation/providers/statistics_providers.dart';
import 'package:deen_companion/features/statistics/presentation/screens/group_statistics_screen.dart';
import 'package:deen_companion/features/statistics/presentation/widgets/stats_chart_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import '_stats_support.dart';

class _Session extends AuthSessionNotifier {
  _Session(this.id);
  final String id;
  @override
  AuthSession build() => AuthSession(userId: id, email: '$id@b.c', name: id);
}

const _detail = GroupDetail(
  id: 'g1',
  name: 'Family',
  members: [
    GroupMember(
      userId: 'u1',
      name: 'Alee',
      email: 'a@b.c',
      role: GroupRole.admin,
    ),
    GroupMember(
      userId: 'u2',
      name: 'Sara',
      email: 's@b.c',
      role: GroupRole.member,
    ),
  ],
);

Future<void> settle(WidgetTester tester, {int frames = 8}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
}

Future<void> pump(
  WidgetTester tester,
  FakeStatsRepo repo, {
  String me = 'u1',
  double width = 390,
  double textScale = 1,
}) async {
  tester.view.physicalSize = Size(width * 3, 2400 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authSessionProvider.overrideWith(() => _Session(me)),
        groupDetailProvider('g1').overrideWith((ref) async => _detail),
        statisticsRepositoryProvider.overrideWithValue(repo),
        statsClockProvider.overrideWithValue(() => DateTime(2026, 10, 19)),
      ],
      child: ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, _) => MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: const GroupStatisticsScreen(groupId: 'g1'),
        ),
      ),
    ),
  );
  await settle(tester);
}

Rect barsBox(WidgetTester tester) {
  return tester.getRect(find.byKey(const Key('stats-bars')));
}

void main() {
  setUpAll(() => FlavorConfig(flavor: Flavor.dev, enableLogging: false));

  group('the screen', () {
    testWidgets('is the app\'s hero, then one chart, then the members', (
      tester,
    ) async {
      await pump(tester, FakeStatsRepo());
      expect(find.text('Statistics'), findsWidgets);
      expect(find.text('Family'), findsOneWidget);
      final chart = tester.getTopLeft(find.text('Daily activity')).dy;
      final members = tester.getTopLeft(find.text('Members')).dy;
      expect(chart, lessThan(members));
      expect(find.byType(StatsChartPanel), findsOneWidget);
    });

    testWidgets('the hero answers the first questions at a glance', (
      tester,
    ) async {
      await pump(tester, FakeStatsRepo());
      expect(find.text('6 of 8 on track today'), findsOneWidget);
      expect(find.text('75% average'), findsOneWidget);
      expect(find.text('You 83% complete'), findsOneWidget);
    });

    testWidgets('has none of the earlier tabs, cards, tiles or legends', (
      tester,
    ) async {
      await pump(tester, FakeStatsRepo());
      for (final gone in [
        'Overview',
        'Attention',
        'By prayer',
        'Day by day',
        'Trend',
        'Compare members',
      ]) {
        expect(find.text(gone), findsNothing, reason: gone);
      }
    });
  });

  group('the chart', () {
    testWidgets('starts on the group, on today, in plain words', (
      tester,
    ) async {
      await pump(tester, FakeStatsRepo());
      expect(find.text('Group'), findsOneWidget);
      expect(find.text('You'), findsOneWidget);
      expect(find.textContaining('Mon 19 Oct · today, so far'), findsOneWidget);
      expect(find.text('3 of 8 members reached the goal'), findsOneWidget);
      expect(find.text('38%'), findsOneWidget);
      expect(find.text('avg 75%'), findsOneWidget);
    });

    testWidgets('tapping a day reads it', (tester) async {
      await pump(tester, FakeStatsRepo());
      final box = barsBox(tester);
      await tester.tapAt(Offset(box.left + 8, box.center.dy));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Sun 18 Oct'), findsOneWidget);
      expect(find.text('6 of 8 members reached the goal'), findsOneWidget);
      expect(find.text('75%'), findsOneWidget);
    });

    testWidgets('dragging across scrubs between days', (tester) async {
      await pump(tester, FakeStatsRepo());
      final box = barsBox(tester);
      final g = await tester.startGesture(Offset(box.left + 8, box.center.dy));
      await g.moveTo(Offset(box.right - 8, box.center.dy));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.textContaining('Mon 19 Oct'), findsOneWidget);
      await g.up();
    });

    testWidgets('"You" shows your own days, in prayers', (tester) async {
      await pump(tester, FakeStatsRepo());
      await tester.tap(find.text('You'));
      await settle(tester, frames: 4);
      expect(find.text('1 of 5 prayers'), findsOneWidget);
      expect(find.text('20%'), findsOneWidget);
      expect(find.text('avg 83%'), findsOneWidget);
    });

    testWidgets('the period changes how far back it looks', (tester) async {
      final repo = FakeStatsRepo();
      await pump(tester, repo);
      await tester.tap(find.text('7D'));
      await settle(tester, frames: 4);
      expect(repo.froms, contains('2026-10-13'));
      await tester.tap(find.text('90D'));
      await settle(tester, frames: 4);
      expect(repo.froms, contains('2026-07-22'));
    });

    testWidgets('a failure says so, and Try again loads it', (tester) async {
      final repo = FakeStatsRepo()..overview = offlineStats;
      await pump(tester, repo);
      expect(find.text('Try again'), findsWidgets);
      repo.overview = FakeStatsRepo().overview;
      await tester.tap(find.text('Try again').first);
      await settle(tester, frames: 4);
      expect(find.text('3 of 8 members reached the goal'), findsOneWidget);
    });

    testWidgets('nothing to chart yet says so', (tester) async {
      final repo = FakeStatsRepo();
      repo.overview = const Success(
        GroupOverview(
          memberCount: 1,
          totals: GroupTotals(
            prayersLogged: 0,
            points: 0,
            perfectMemberDays: 0,
            membersActiveToday: 0,
          ),
          averageParticipationPercent: null,
          daily: [],
        ),
      );
      await pump(tester, repo);
      expect(find.textContaining('Nothing to chart yet'), findsOneWidget);
    });
  });

  group('the members', () {
    testWidgets('are listed as on the group screen, with their figures', (
      tester,
    ) async {
      await pump(tester, FakeStatsRepo());
      expect(find.text('Sara'), findsOneWidget);
      expect(find.text('Newbie'), findsOneWidget);
      expect(find.text('Alee (you)'), findsOneWidget);
      expect(find.text('450 pts · 90% complete'), findsOneWidget);
      expect(find.text('5 pts · no completion yet'), findsOneWidget);
      expect(find.text('9d'), findsOneWidget);
    });

    testWidgets('tapping one puts them on the chart, under their own pill', (
      tester,
    ) async {
      final repo = FakeStatsRepo();
      await pump(tester, repo);
      await tester.ensureVisible(find.text('Sara'));
      await tester.tap(find.text('Sara'));
      await settle(tester, frames: 6);
      expect(repo.calls, contains('memberDetail:u2'));
      expect(
        find.text('Sara'),
        findsNWidgets(2),
        reason: 'the pill and the row',
      );
      expect(find.text('avg 90%'), findsOneWidget);
      expect(find.text('Group'), findsOneWidget, reason: 'the others stay');
    });

    testWidgets('tapping yourself shows "You", not a second pill', (
      tester,
    ) async {
      await pump(tester, FakeStatsRepo());
      await tester.ensureVisible(find.text('Alee (you)'));
      await tester.tap(find.text('Alee (you)'));
      await settle(tester, frames: 6);
      expect(find.text('avg 83%'), findsOneWidget);
    });

    testWidgets('the admin sees who needs attention, under their name', (
      tester,
    ) async {
      await pump(tester, FakeStatsRepo(), me: 'u1');
      expect(find.text('Never logged a prayer'), findsOneWidget);
    });

    testWidgets('a member sees no flags and never asks for them', (
      tester,
    ) async {
      final repo = FakeStatsRepo();
      await pump(tester, repo, me: 'u2');
      expect(find.text('Never logged a prayer'), findsNothing);
      expect(repo.calls, isNot(contains('attention')));
    });

    testWidgets('a failing attention report does not spoil the list', (
      tester,
    ) async {
      final repo = FakeStatsRepo()..attentionResult = offlineStats;
      await pump(tester, repo, me: 'u1');
      expect(find.text('Sara'), findsOneWidget);
      expect(find.text('Never logged a prayer'), findsNothing);
    });

    testWidgets('a member whose days fail to load shows Try again', (
      tester,
    ) async {
      final repo = FakeStatsRepo()..detail = offlineStats;
      await pump(tester, repo);
      await tester.ensureVisible(find.text('Sara'));
      await tester.tap(find.text('Sara'));
      await settle(tester, frames: 6);
      expect(find.text('Try again'), findsWidgets);
    });

    testWidgets('the members failing to load offers a retry', (tester) async {
      final repo = FakeStatsRepo()..members = offlineStats;
      await pump(tester, repo);
      expect(find.text('Sara'), findsNothing);
      expect(find.textContaining('Try again'), findsWidgets);
    });
  });

  group('layout', () {
    testWidgets('does not overflow on a narrow phone at large text', (
      tester,
    ) async {
      await pump(tester, FakeStatsRepo(), width: 320, textScale: 1.5);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('You'));
      await settle(tester, frames: 4);
      expect(tester.takeException(), isNull);
    });
  });
}
