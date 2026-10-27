import 'package:deen_companion/features/group_live/presentation/providers/group_live_store.dart';
import 'package:deen_companion/core/config/flavor_config.dart';
import 'package:deen_companion/features/auth/domain/entities/auth_session.dart';
import 'package:deen_companion/features/auth/presentation/providers/auth_session_provider.dart';
import 'package:deen_companion/features/groups/domain/entities/group.dart';
import 'package:deen_companion/features/groups/domain/entities/group_detail.dart';
import 'package:deen_companion/features/groups/presentation/providers/groups_providers.dart';
import 'package:deen_companion/features/groups/presentation/screens/group_detail_screen.dart';
import 'package:deen_companion/features/prayer_logs/presentation/providers/prayer_logs_providers.dart';
import 'package:deen_companion/features/statistics/presentation/providers/statistics_providers.dart';
import 'package:deen_companion/features/statistics/presentation/screens/group_statistics_screen.dart';
import 'package:deen_companion/features/statistics/presentation/widgets/stats_chart_panel.dart';
import 'package:deen_companion/features/streaks/presentation/providers/streaks_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../streaks/_streaks_support.dart';
import '_stats_support.dart';
import '../group_live/_live_support.dart';

class _Session extends AuthSessionNotifier {
  @override
  AuthSession build() =>
      const AuthSession(userId: 'u1', email: 'a@b.c', name: 'Alee');
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
  ],
);

Future<void> pump(WidgetTester tester, {FakeStreaksRepo? streaks}) async {
  tester.view.physicalSize = const Size(390 * 3, 1600 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const GroupDetailScreen(groupId: 'g1'),
      ),
      GoRoute(
        path: '/groups/:groupId/stats',
        builder: (_, state) =>
            GroupStatisticsScreen(groupId: state.pathParameters['groupId']!),
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        groupSummaryRemoteDataSourceProvider.overrideWithValue(
          FakeSummaryRemote(),
        ),
        authSessionProvider.overrideWith(_Session.new),
        groupDetailProvider('g1').overrideWith((ref) async => _detail),
        groupPrayersProvider.overrideWith((ref, key) async => const []),
        streaksRepositoryProvider.overrideWithValue(
          streaks ?? FakeStreaksRepo(),
        ),
        statisticsRepositoryProvider.overrideWithValue(FakeStatsRepo()),
      ],
      child: ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, _) => MaterialApp.router(routerConfig: router),
      ),
    ),
  );
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
}

void main() {
  setUpAll(() => FlavorConfig(flavor: Flavor.dev, enableLogging: false));

  testWidgets(
    '"View statistics" sits under the longest streak, in the same box',
    (tester) async {
      await pump(tester);
      final longest = tester
          .getTopLeft(find.textContaining('Longest streak'))
          .dy;
      final button = tester.getTopLeft(find.text('View statistics')).dy;
      final summary = tester.getTopLeft(find.text('Goal met today')).dy;
      expect(button, greaterThan(longest));
      expect(summary, lessThan(longest));

      // Same container: one ancestor holds the summary, the line and the button.
      final box = find.ancestor(
        of: find.text('Goal met today'),
        matching: find.byWidgetPredicate(
          (w) =>
              w is Container &&
              w.decoration is BoxDecoration &&
              (w.decoration! as BoxDecoration).borderRadius ==
                  BorderRadius.circular(20.r),
        ),
      );
      expect(
        find.descendant(of: box.first, matching: find.text('View statistics')),
        findsOneWidget,
      );
    },
  );

  testWidgets('tapping it opens the statistics for this group', (tester) async {
    await pump(tester);
    await tester.tap(find.text('View statistics'));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    expect(find.byType(GroupStatisticsScreen), findsOneWidget);
    expect(find.byType(StatsChartPanel), findsOneWidget);
  });

  testWidgets('with no streak board, a Statistics chip keeps it reachable', (
    tester,
  ) async {
    await pump(tester, streaks: FakeStreaksRepo()..board = offline);
    expect(find.text('View statistics'), findsNothing);
    expect(find.text('Statistics'), findsOneWidget);
    await tester.tap(find.text('Statistics'));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    expect(find.byType(GroupStatisticsScreen), findsOneWidget);
  });
}
