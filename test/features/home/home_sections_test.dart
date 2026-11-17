import 'package:deen_companion/core/config/flavor_config.dart';
import 'package:deen_companion/core/usecase/usecase.dart';
import 'package:deen_companion/features/auth/presentation/providers/auth_session_provider.dart';
import 'package:deen_companion/features/group_live/presentation/providers/group_live_store.dart';
import 'package:deen_companion/features/group_live/presentation/providers/realtime_providers.dart';
import 'package:deen_companion/features/groups/domain/entities/group.dart';
import 'package:deen_companion/features/groups/presentation/providers/groups_providers.dart';
import 'package:deen_companion/features/home/presentation/widgets/home_groups_section.dart';
import 'package:deen_companion/features/home/presentation/widgets/home_prayer_strip.dart';
import 'package:deen_companion/features/prayer_logs/domain/current_prayer.dart';
import 'package:deen_companion/features/prayer_logs/domain/prayer_log.dart';
import 'package:deen_companion/features/prayer_logs/presentation/providers/prayer_logs_providers.dart';
import 'package:deen_companion/features/prayer_times/domain/entities/prayer_times.dart';
import 'package:deen_companion/features/prayer_times/presentation/providers/prayer_times_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../group_live/_live_support.dart';
import '../prayer_logs/presentation/_prayer_log_test_support.dart';
import '../snaps/snap_fakes.dart';

final _times = PrayerTimes(
  fajr: DateTime(2026, 11, 16, 5, 12),
  dhuhr: DateTime(2026, 11, 16, 11, 52),
  asr: DateTime(2026, 11, 16, 15, 32),
  maghrib: DateTime(2026, 11, 16, 17, 13),
  isha: DateTime(2026, 11, 16, 18, 36),
  hijriDate: '',
);

class _FakeTimes extends PrayerTimesNotifier {
  @override
  PrayerTimes? readCache() => _times;

  @override
  Future<Result<PrayerTimes>> fetchFresh() async => Success(_times);
}

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  bool signedIn = true,
  List<Group> groups = sampleGroups,
  CurrentPrayerState? prayer,
  List<PrayerLog> logs = const [],
  List<String>? visited,
}) async {
  tester.view.physicalSize = const Size(390 * 3, 900 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => Scaffold(body: SingleChildScrollView(child: child)),
      ),
      GoRoute(
        path: '/groups/:id',
        builder: (_, s) {
          visited?.add('/groups/${s.pathParameters['id']}');
          return const Scaffold(body: Text('GROUP'));
        },
      ),
      GoRoute(
        path: '/signup',
        builder: (_, s) {
          visited?.add(s.uri.toString());
          return const Scaffold(body: Text('SIGN UP'));
        },
      ),
      GoRoute(
        path: '/prayer-log',
        builder: (_, _) {
          visited?.add('/prayer-log');
          return const Scaffold(body: Text('DAY VIEW'));
        },
      ),
      GoRoute(
        path: '/snap',
        builder: (_, _) {
          visited?.add('/snap');
          return const Scaffold(body: Text('SNAP FLOW'));
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
        prayerLogsProvider.overrideWith((ref, date) async => logs),
        prayerTimesNotifierProvider.overrideWith(_FakeTimes.new),
        // The group rows' live numbers and feed: not reachable here, so the
        // rows show their fallbacks.
        groupSummaryRemoteDataSourceProvider.overrideWithValue(
          FakeSummaryRemote(),
        ),
        groupPrayersProvider.overrideWith((ref, key) async => const []),
        realtimeServiceProvider.overrideWithValue(null),
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

void main() {
  setUpAll(() => FlavorConfig(flavor: Flavor.dev, enableLogging: false));

  group('Groups on Home', () {
    testWidgets('lists the user\'s groups under a Groups heading', (
      tester,
    ) async {
      await _pump(tester, const HomeGroupsSection());
      expect(find.text('Groups'), findsOneWidget);
      expect(find.text('+ New'), findsOneWidget);
      expect(find.text('Search groups'), findsOneWidget);
      for (final name in ['Namaz Family', 'Quran Circle', 'Friday Friends']) {
        expect(find.text(name), findsOneWidget);
      }
      // Until the live numbers arrive a row shows the member count.
      expect(find.text('8 members'), findsOneWidget);
      expect(find.text('1 member'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('tapping a group opens it', (tester) async {
      final visited = <String>[];
      await _pump(tester, const HomeGroupsSection(), visited: visited);
      await tester.tap(find.text('Quran Circle'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(visited, ['/groups/g2']);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('search narrows the list', (tester) async {
      await _pump(tester, const HomeGroupsSection());
      await tester.enterText(find.byType(TextField), 'quran');
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Quran Circle'), findsOneWidget);
      expect(find.text('Namaz Family'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('no groups: the empty state, with a way to create one', (
      tester,
    ) async {
      await _pump(tester, const HomeGroupsSection(), groups: const []);
      expect(find.text('Namaz Family'), findsNothing);
      expect(find.text('+ New'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a guest who taps + New is sent to sign up, back to Home', (
      tester,
    ) async {
      final visited = <String>[];
      await _pump(
        tester,
        const HomeGroupsSection(),
        signedIn: false,
        groups: const [],
        visited: visited,
      );
      await tester.tap(find.text('+ New'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(visited.single, startsWith('/signup'));
      expect(visited.single, contains('redirect=%2F'));
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('Prayer strip on Home', () {
    testWidgets('logged prayers, the open one, and the rest, with times', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await _pump(
        tester,
        const HomePrayerStrip(),
        // Fajr and Dhuhr logged; Asr is open and not logged.
        logs: [
          logOf(PrayerName.fajr, id: 'a'),
          logOf(PrayerName.dhuhr, id: 'b'),
        ],
      );
      // The card is one tappable node, so the slots' labels merge into it.
      expect(find.bySemanticsLabel(RegExp('Fajr logged')), findsWidgets);
      expect(find.bySemanticsLabel(RegExp('Dhuhr logged')), findsWidgets);
      expect(
        find.bySemanticsLabel(RegExp('Asr open, tap to send a snap')),
        findsWidgets,
      );
      expect(find.bySemanticsLabel(RegExp('Maghrib not yet')), findsWidgets);
      expect(find.bySemanticsLabel(RegExp('Isha not yet')), findsWidgets);
      expect(find.text('5:12 AM'), findsOneWidget);
      expect(find.text('6:36 PM'), findsOneWidget);
      semantics.dispose();
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a prayer whose time closed unlogged is red with a dash', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      // Asr is open. Only Fajr was logged, so Dhuhr's time has closed.
      await _pump(
        tester,
        const HomePrayerStrip(),
        logs: [logOf(PrayerName.fajr, id: 'a')],
      );
      expect(find.bySemanticsLabel(RegExp('Dhuhr missed')), findsWidgets);
      expect(find.byIcon(Icons.remove_rounded), findsOneWidget);
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
      // Just the five prayers: no title and no count on the card.
      expect(find.text('Today’s prayers'), findsNothing);
      expect(find.text('1 of 5'), findsNothing);
      semantics.dispose();
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('nothing is called missed before the schedule is known', (
      tester,
    ) async {
      await _pump(
        tester,
        const HomePrayerStrip(),
        // No open prayer and nothing next: no basis to say anything closed.
        prayer: CurrentPrayerState(now: DateTime.now()),
      );
      expect(find.byIcon(Icons.remove_rounded), findsNothing);
      expect(find.byIcon(Icons.photo_camera_rounded), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('once the open prayer is logged the camera becomes a tick', (
      tester,
    ) async {
      await _pump(
        tester,
        const HomePrayerStrip(),
        prayer: openState(logged: true, logId: 'l1'),
        logs: [logOf(PrayerName.asr, id: 'asr')],
      );
      expect(find.byIcon(Icons.photo_camera_rounded), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });

    group('the camera cue', () {
      /// How big the camera circle is drawn right now (1.0 at rest).
      double cameraScale(WidgetTester tester) => tester
          .widget<Transform>(
            find
                .ancestor(
                  of: find.byIcon(Icons.photo_camera_rounded),
                  matching: find.byType(Transform),
                )
                .first,
          )
          .transform
          .getMaxScaleOnAxis();

      testWidgets('bounces gently, then rests, again and again', (
        tester,
      ) async {
        await _pump(tester, const HomePrayerStrip());
        // Sample a little over two full cycles (2.6 s each).
        final seen = <double>[];
        for (var i = 0; i < 110; i++) {
          await tester.pump(const Duration(milliseconds: 50));
          seen.add(cameraScale(tester));
        }
        final peak = seen.reduce((a, b) => a > b ? a : b);
        final rest = seen.reduce((a, b) => a < b ? a : b);
        expect(peak, greaterThan(1.05), reason: 'it does move');
        expect(peak, lessThan(1.15), reason: 'subtle, not jumpy');
        expect(rest, closeTo(1.0, 0.001), reason: 'and it rests');
        // It bounced more than once: the scale rose past 1.05 in two separate
        // stretches.
        var rises = 0;
        var up = false;
        for (final v in seen) {
          if (v > 1.05 && !up) {
            rises++;
            up = true;
          } else if (v <= 1.05) {
            up = false;
          }
        }
        expect(rises, greaterThanOrEqualTo(2));
        await tester.pumpWidget(const SizedBox());
      });

      testWidgets('stays still when the system asks for reduced motion', (
        tester,
      ) async {
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures(disableAnimations: true);
        addTearDown(
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
        );
        await _pump(tester, const HomePrayerStrip());
        await tester.pump(const Duration(milliseconds: 390));
        expect(cameraScale(tester), closeTo(1.0, 0.001));
        await tester.pumpWidget(const SizedBox());
      });

      testWidgets('stays still when a snap cannot be sent', (tester) async {
        // The open prayer is logged and every group has its snap, so there is
        // nothing to send; with no logs the prayer still reads as open.
        await _pump(
          tester,
          const HomePrayerStrip(),
          prayer: openState(canSend: false, sent: const [], unsent: const []),
        );
        await tester.pump(const Duration(milliseconds: 390));
        expect(find.byIcon(Icons.photo_camera_rounded), findsOneWidget);
        expect(cameraScale(tester), closeTo(1.0, 0.001));
        await tester.pumpWidget(const SizedBox());
      });
    });

    testWidgets('the camera on the open prayer starts the snap flow', (
      tester,
    ) async {
      final visited = <String>[];
      await _pump(tester, const HomePrayerStrip(), visited: visited);
      await tester.tap(find.byIcon(Icons.photo_camera_rounded));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 150));
      }
      expect(visited, ['/snap']);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('tapping the card opens the day view', (tester) async {
      final visited = <String>[];
      await _pump(tester, const HomePrayerStrip(), visited: visited);
      await tester.tap(find.text('Maghrib'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(visited, ['/prayer-log']);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('guests do not see it', (tester) async {
      await _pump(tester, const HomePrayerStrip(), signedIn: false);
      expect(find.text('Fajr'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });
  });
}
