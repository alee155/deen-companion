import 'package:deen_companion/core/config/flavor_config.dart';
import 'package:deen_companion/core/theme/app_colors.dart';
import 'package:deen_companion/features/auth/presentation/providers/auth_session_provider.dart';
import 'package:deen_companion/features/groups/domain/entities/group.dart';
import 'package:deen_companion/features/groups/presentation/providers/groups_providers.dart';
import 'package:deen_companion/features/groups/presentation/screens/groups_screen.dart';
import 'package:deen_companion/features/groups/presentation/widgets/send_snap_button.dart';
import 'package:deen_companion/features/prayer_logs/domain/current_prayer.dart';
import 'package:deen_companion/features/prayer_times/domain/entities/prayer_times.dart';
import 'package:deen_companion/features/prayer_logs/presentation/providers/prayer_logs_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../prayer_logs/presentation/_prayer_log_test_support.dart';
import '../../snaps/snap_fakes.dart';

Future<void> _pump(
  WidgetTester tester, {
  bool signedIn = true,
  List<Group> groups = sampleGroups,
  CurrentPrayerState? prayer,
  double navBarHeight = 0,
  List<String>? visited,
}) async {
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => const GroupsScreen()),
      GoRoute(
        path: '/snap',
        builder: (_, _) {
          visited?.add('/snap');
          return const Scaffold(body: Text('SNAP FLOW'));
        },
      ),
      GoRoute(
        path: '/signup',
        builder: (_, s) {
          visited?.add(s.uri.toString());
          return const Scaffold(body: Text('SIGN UP'));
        },
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authSessionProvider.overrideWith(
          signedIn ? SignedIn.new : SignedOut.new,
        ),
        myGroupsProvider.overrideWith(() => FakeMyGroups(groups)),
        currentPrayerProvider.overrideWith(
          () => FixedCurrent(prayer ?? openState()),
        ),
      ],
      child: ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, _) => MaterialApp.router(
          routerConfig: router,
          // Stands in for the floating navigation bar the shell adds below.
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(padding: EdgeInsets.only(bottom: navBarHeight)),
            child: child!,
          ),
        ),
      ),
    ),
  );
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
}

bool _isGrey(WidgetTester tester) {
  final material = tester.widget<Material>(
    find.descendant(
      of: find.byType(SendSnapButton),
      matching: find.byType(Material),
    ),
  );
  return material.color != AppColors.emeraldInk;
}

Future<void> _tapCamera(WidgetTester tester) async {
  await tester.tap(find.byType(SendSnapButton));
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}

void main() {
  setUpAll(() => FlavorConfig(flavor: Flavor.dev, enableLogging: false));

  testWidgets('the groups list has a camera button', (tester) async {
    await _pump(tester);
    expect(find.byType(SendSnapButton), findsOneWidget);
    expect(find.byIcon(Icons.camera_alt_rounded), findsOneWidget);
    expect(_isGrey(tester), isFalse);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('tapping it opens the snap flow, with no group chosen', (
    tester,
  ) async {
    final visited = <String>[];
    await _pump(tester, visited: visited);
    await _tapCamera(tester);
    expect(find.text('SNAP FLOW'), findsOneWidget);
    expect(visited, ['/snap']);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('it sits at the bottom right, clear of the navigation bar', (
    tester,
  ) async {
    await _pump(tester, navBarHeight: 110);
    final box = tester.getRect(find.byType(SendSnapButton));
    expect(box.right, closeTo(390 - 20, 1));
    expect(
      box.bottom,
      lessThanOrEqualTo(844 - 110),
      reason: 'not hidden behind the bar',
    );
    expect(box.bottom, greaterThan(844 - 110 - 40), reason: 'right above it');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('it does not cover the groups it floats over', (tester) async {
    await _pump(tester);
    expect(find.text('Namaz Family'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  group('when a snap cannot be sent', () {
    testWidgets('this prayer already has its snap: grey, and says so', (
      tester,
    ) async {
      final visited = <String>[];
      await _pump(
        tester,
        prayer: openState(logged: true, logId: 'l1'),
        visited: visited,
      );
      expect(find.byType(SendSnapButton), findsOneWidget);
      expect(_isGrey(tester), isTrue);

      await _tapCamera(tester);
      expect(
        find.textContaining('You’ve already sent your Asr snap'),
        findsOneWidget,
      );
      expect(visited, isEmpty);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('no prayer open: grey, explains the allowed time', (
      tester,
    ) async {
      await _pump(
        tester,
        prayer: CurrentPrayerState(
          now: DateTime.now(),
          next: NextPrayer(
            prayer: PrayerName.isha,
            startsAt: DateTime.now().add(const Duration(hours: 2)),
          ),
        ),
      );
      expect(_isGrey(tester), isTrue);
      await _tapCamera(tester);
      expect(
        find.textContaining(
          'Snaps can only be sent while a prayer time is open.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('Isha starts at'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('no groups yet: grey, says to join or create one', (
      tester,
    ) async {
      await _pump(tester, groups: const []);
      expect(find.byType(SendSnapButton), findsOneWidget);
      expect(_isGrey(tester), isTrue);
      await _tapCamera(tester);
      expect(
        find.text('Join or create a group to start sending snaps.'),
        findsOneWidget,
      );
      expect(find.text('SNAP FLOW'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('the reason about groups wins over the one about prayers', (
      tester,
    ) async {
      await _pump(
        tester,
        groups: const [],
        prayer: openState(logged: true, logId: 'l1'),
      );
      await _tapCamera(tester);
      expect(find.textContaining('Join or create a group'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('a guest', () {
    testWidgets('sees it enabled, and is sent to sign up', (tester) async {
      final visited = <String>[];
      await _pump(tester, signedIn: false, groups: const [], visited: visited);
      expect(_isGrey(tester), isFalse);

      await _tapCamera(tester);
      expect(find.text('SIGN UP'), findsOneWidget);
      expect(visited.single, startsWith('/signup'));
      expect(visited.single, contains('redirect=%2Fgroups'));
      await tester.pumpWidget(const SizedBox());
    });
  });

  testWidgets('searching with no matches keeps the camera', (tester) async {
    await _pump(tester);
    await tester.enterText(find.byType(TextField), 'zzzz');
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(SendSnapButton), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
