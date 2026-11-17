import 'package:deen_companion/core/config/flavor_config.dart';
import 'package:deen_companion/features/auth/presentation/providers/auth_session_provider.dart';
import 'package:deen_companion/features/groups/domain/entities/group.dart';
import 'package:deen_companion/features/groups/presentation/providers/groups_providers.dart';
import 'package:deen_companion/features/prayer_logs/domain/current_prayer.dart';
import 'package:deen_companion/features/prayer_logs/presentation/providers/prayer_logs_providers.dart';
import 'package:deen_companion/features/prayer_times/domain/entities/prayer_times.dart';
import 'package:deen_companion/features/snaps/presentation/snap_entry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../prayer_logs/presentation/_prayer_log_test_support.dart';
import 'snap_fakes.dart';

/// The camera button in the bottom bar, as the old Groups screen's camera
/// behaved: [openSnapFromNav].
Future<void> _pump(
  WidgetTester tester, {
  bool signedIn = true,
  List<Group> groups = sampleGroups,
  CurrentPrayerState? prayer,
  List<String>? visited,
}) async {
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => Scaffold(
          body: Consumer(
            builder: (context, ref, _) {
              // As the shell does, so a tap is answered from loaded data.
              ref.watch(snapNavReadyProvider);
              return Center(
                child: TextButton(
                  onPressed: () => openSnapFromNav(context, ref),
                  child: const Text('CAMERA'),
                ),
              );
            },
          ),
        ),
      ),
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
        builder: (_, _) => MaterialApp.router(routerConfig: router),
      ),
    ),
  );
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
}

Future<void> _tapCamera(WidgetTester tester) async {
  await tester.tap(find.text('CAMERA'));
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}

void main() {
  setUpAll(() => FlavorConfig(flavor: Flavor.dev, enableLogging: false));

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

  group('when a snap cannot be sent', () {
    testWidgets('every group already has its snap: says so', (tester) async {
      final visited = <String>[];
      await _pump(
        tester,
        prayer: openState(logged: true, logId: 'l1'),
        visited: visited,
      );
      await _tapCamera(tester);
      expect(
        find.textContaining('You’ve sent your Asr snap to all your groups'),
        findsOneWidget,
      );
      expect(visited, isEmpty);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('no prayer open: explains the allowed time', (tester) async {
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

    testWidgets('no groups yet: says to join or create one', (tester) async {
      await _pump(tester, groups: const []);
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

  testWidgets('a guest is sent to sign up, and comes back to Home', (
    tester,
  ) async {
    final visited = <String>[];
    await _pump(tester, signedIn: false, groups: const [], visited: visited);
    await _tapCamera(tester);
    expect(find.text('SIGN UP'), findsOneWidget);
    expect(visited.single, startsWith('/signup'));
    expect(visited.single, contains('redirect=%2F'));
    expect(visited.single, isNot(contains('redirect=%2Fgroups')));
    await tester.pumpWidget(const SizedBox());
  });
}
