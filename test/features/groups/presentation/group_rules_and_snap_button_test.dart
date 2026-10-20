import 'package:deen_companion/core/config/flavor_config.dart';
import 'package:deen_companion/core/usecase/usecase.dart';
import 'package:deen_companion/features/auth/domain/entities/auth_session.dart';
import 'package:deen_companion/features/auth/presentation/providers/auth_session_provider.dart';
import 'package:deen_companion/features/groups/domain/entities/group.dart';
import 'package:deen_companion/features/groups/domain/entities/group_detail.dart';
import 'package:deen_companion/features/groups/presentation/providers/groups_providers.dart';
import 'package:deen_companion/features/groups/presentation/screens/group_detail_screen.dart';
import 'package:deen_companion/features/groups/presentation/widgets/send_snap_button.dart';
import 'package:deen_companion/features/points/presentation/providers/points_providers.dart';
import 'package:deen_companion/features/points/presentation/screens/points_rules_screen.dart';
import 'package:deen_companion/features/prayer_logs/presentation/providers/prayer_logs_providers.dart';
import 'package:deen_companion/features/streaks/presentation/providers/streaks_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../streaks/_streaks_support.dart';
import 'package:go_router/go_router.dart';

import '../../points/_points_support.dart';

class _Session extends AuthSessionNotifier {
  final String id;
  _Session(this.id);
  @override
  AuthSession build() => AuthSession(userId: id, email: '$id@b.c', name: id);
}

const _detail = GroupDetail(
  id: 'g1',
  name: 'Namaz Family Group',
  members: [
    GroupMember(
      userId: 'admin1',
      name: 'Alee Khan',
      email: 'a@b.c',
      role: GroupRole.admin,
    ),
    GroupMember(
      userId: 'member1',
      name: 'Sara Ahmed',
      email: 's@b.c',
      role: GroupRole.member,
    ),
  ],
);

Future<void> _pump(WidgetTester tester, {required String me}) async {
  tester.view.physicalSize = const Size(390 * 3, 1400 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const GroupDetailScreen(groupId: 'g1'),
      ),
      GoRoute(
        path: '/points-rules',
        builder: (_, state) =>
            PointsRulesScreen(groupId: state.uri.queryParameters['groupId']),
      ),
      GoRoute(
        path: '/groups/:id/snap',
        builder: (_, _) => const Scaffold(body: Text('SNAP FLOW')),
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authSessionProvider.overrideWith(() => _Session(me)),
        groupDetailProvider('g1').overrideWith((ref) async => _detail),
        groupPrayersProvider.overrideWith((ref, key) async => const []),
        pointsRepositoryProvider.overrideWithValue(
          FakePointsRepo()..result = Success(sampleRules()),
        ),
        streaksRepositoryProvider.overrideWithValue(FakeStreaksRepo()),
      ],
      child: ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, _) => MaterialApp.router(routerConfig: router),
      ),
    ),
  );
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

void main() {
  setUpAll(() => FlavorConfig(flavor: Flavor.dev, enableLogging: false));

  group('Rules entry in the group menu', () {
    testWidgets('an admin sees Rules', (tester) async {
      await _pump(tester, me: 'admin1');
      await tester.tap(find.byIcon(Icons.more_horiz_rounded));
      await _settle(tester);
      expect(find.text('Manage group'), findsOneWidget);
      expect(find.text('Rules'), findsOneWidget);
      expect(find.text('How many points each prayer earns'), findsOneWidget);
      // Admin-only items are still there too.
      expect(find.text('Edit details'), findsOneWidget);
      expect(find.text('Delete group'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a regular member sees Rules too', (tester) async {
      await _pump(tester, me: 'member1');
      await tester.tap(find.byIcon(Icons.more_horiz_rounded));
      await _settle(tester);
      expect(find.text('Group options'), findsOneWidget);
      expect(find.text('Rules'), findsOneWidget);
      expect(find.text('Edit details'), findsNothing);
      expect(find.text('Delete group'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('Rules is the first item in the menu', (tester) async {
      await _pump(tester, me: 'admin1');
      await tester.tap(find.byIcon(Icons.more_horiz_rounded));
      await _settle(tester);
      final rules = tester.getTopLeft(find.text('Rules')).dy;
      expect(rules, lessThan(tester.getTopLeft(find.text('Edit details')).dy));
      expect(rules, lessThan(tester.getTopLeft(find.text('Invite link')).dy));
      await tester.pumpWidget(const SizedBox());
    });

    for (final who in ['admin1', 'member1']) {
      testWidgets('tapping Rules opens the rules screen ($who)', (
        tester,
      ) async {
        await _pump(tester, me: who);
        await tester.tap(find.byIcon(Icons.more_horiz_rounded));
        await _settle(tester);
        await tester.tap(find.text('Rules'));
        await _settle(tester);

        expect(find.byType(PointsRulesScreen), findsOneWidget);
        expect(find.text('Fajr'), findsWidgets);
        expect(find.text('+10 points'), findsOneWidget);
        // The rules screen was opened for this group, so it shows its goal;
        // only the admin gets the controls to change it.
        expect(find.text('Daily goal'), findsWidgets);
        expect(
          find.text('Save goal'),
          who == 'admin1' ? findsOneWidget : findsNothing,
        );
        await tester.pumpWidget(const SizedBox());
      });
    }

    testWidgets('going back returns to the group', (tester) async {
      await _pump(tester, me: 'member1');
      await tester.tap(find.byIcon(Icons.more_horiz_rounded));
      await _settle(tester);
      await tester.tap(find.text('Rules'));
      await _settle(tester);
      await tester.pageBack();
      await _settle(tester);
      expect(find.byType(GroupDetailScreen), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('Send snap button', () {
    testWidgets('is a round camera button with no text label', (tester) async {
      await _pump(tester, me: 'admin1');
      expect(find.byType(SendSnapButton), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsNothing);
      expect(find.text('Send snap'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('opens the snap flow when tapped', (tester) async {
      await _pump(tester, me: 'admin1');
      await tester.tap(find.byType(SendSnapButton));
      await _settle(tester);
      expect(find.text('SNAP FLOW'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('keeps its tooltip and accessibility label', (tester) async {
      await _pump(tester, me: 'admin1');
      expect(
        find.descendant(
          of: find.byType(SendSnapButton),
          matching: find.byTooltip('Send snap'),
        ),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('SendSnapButton on its own', () {
    Future<void> pumpButton(WidgetTester tester, VoidCallback onTap) async {
      await tester.pumpWidget(
        ScreenUtilInit(
          designSize: const Size(390, 844),
          builder: (_, _) => MaterialApp(
            home: Scaffold(
              body: Center(child: SendSnapButton(onPressed: onTap)),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('a white camera icon on a circle', (tester) async {
      await pumpButton(tester, () {});
      final icon = tester.widget<Icon>(find.byIcon(Icons.camera_alt_rounded));
      expect(icon.color, Colors.white);

      final material = tester.widget<Material>(
        find.descendant(
          of: find.byType(SendSnapButton),
          matching: find.byType(Material),
        ),
      );
      expect(material.shape, isA<CircleBorder>());
    });

    testWidgets('is as wide as it is tall', (tester) async {
      await pumpButton(tester, () {});
      final size = tester.getSize(find.byType(SendSnapButton));
      expect(size.width, closeTo(size.height, 0.01));
    });

    testWidgets('glows: a circular outer shadow in the brand colour', (
      tester,
    ) async {
      await pumpButton(tester, () {});
      final container = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(SendSnapButton),
              matching: find.byType(Container),
            )
            .first,
      );
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.shape, BoxShape.circle);
      final shadows = decoration.boxShadow!;
      expect(
        shadows.length,
        greaterThanOrEqualTo(2),
        reason: 'tight + wide glow',
      );
      for (final s in shadows) {
        expect(s.blurRadius, greaterThan(10));
        expect(s.color.a, greaterThan(0));
        expect(s.offset, Offset.zero, reason: 'a glow, not a drop shadow');
      }
    });

    testWidgets('calls back when tapped', (tester) async {
      var taps = 0;
      await pumpButton(tester, () => taps++);
      await tester.tap(find.byType(SendSnapButton));
      expect(taps, 1);
    });
  });
}
