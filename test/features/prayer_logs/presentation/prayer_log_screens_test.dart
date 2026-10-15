import 'package:deen_companion/core/config/flavor_config.dart';
import 'package:deen_companion/core/permissions/camera_permission_service.dart';
import 'package:deen_companion/core/usecase/usecase.dart';
import 'package:deen_companion/features/auth/presentation/providers/auth_session_provider.dart';
import 'package:deen_companion/features/prayer_logs/domain/prayer_log.dart';
import 'package:deen_companion/features/prayer_logs/presentation/providers/prayer_log_composer.dart';
import 'package:deen_companion/features/prayer_logs/presentation/providers/prayer_logs_providers.dart';
import 'package:deen_companion/features/prayer_logs/presentation/screens/prayer_log_flow_screen.dart';
import 'package:deen_companion/features/prayer_logs/presentation/screens/prayer_logs_screen.dart';
import 'package:deen_companion/features/prayer_times/domain/entities/prayer_times.dart';
import 'package:deen_companion/features/snaps/presentation/providers/snap_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../snaps/snap_fakes.dart';
import '_prayer_log_test_support.dart';

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}

void _bigScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

void main() {
  setUpAll(() => FlavorConfig(flavor: Flavor.dev, enableLogging: false));

  group('log flow', () {
    late FakeCameraService camera;
    late ScriptedLogsRepo repo;

    Future<ProviderContainer> pump(WidgetTester tester) async {
      _bigScreen(tester);
      camera = FakeCameraService();
      repo = ScriptedLogsRepo();
      final container = ProviderContainer(
        overrides: [
          authSessionProvider.overrideWith(SignedIn.new),
          currentPrayerProvider.overrideWith(() => FixedCurrent(openState())),
          prayerLogsRepositoryProvider.overrideWithValue(repo),
          cameraServiceProvider.overrideWithValue(camera),
          snapImageProcessorProvider.overrideWithValue(FakeProcessor()),
          cameraPermissionServiceProvider.overrideWithValue(
            FakeCameraPermission(),
          ),
        ],
      );
      addTearDown(container.dispose);

      final popped = <Object?>[];
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const Scaffold(body: Text('HOME')),
          ),
          GoRoute(
            path: '/prayer-log/new',
            builder: (_, _) => const PrayerLogFlowScreen(),
          ),
        ],
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: ScreenUtilInit(
            designSize: const Size(390, 844),
            builder: (_, _) => MaterialApp.router(routerConfig: router),
          ),
        ),
      );
      router.push<bool>('/prayer-log/new').then(popped.add);
      await _settle(tester);
      addTearDown(() => expect(popped.length, lessThanOrEqualTo(1)));
      return container;
    }

    testWidgets('opens the camera labelled with the open prayer', (
      tester,
    ) async {
      await pump(tester);
      expect(camera.opened, isNotEmpty);
      expect(find.text('Log Asr'), findsOneWidget);
    });

    testWidgets('confirm step logs and closes the flow', (tester) async {
      final c = await pump(tester);
      repo.logResult = Success(logOf(PrayerName.asr));
      final n = c.read(prayerLogComposerProvider.notifier);
      await n.onCaptured('/tmp/a.jpg');
      await n.onCropped(tinyPng);
      await _settle(tester);

      expect(find.text('Confirm'), findsOneWidget);
      await tester.tap(find.text('Log Asr'));
      await _settle(tester);

      expect(repo.logged, ['/tmp/prepared.jpg']);
      expect(find.text('HOME'), findsOneWidget, reason: 'flow closed');
    });

    testWidgets('a rejected upload keeps the flow open with the reason', (
      tester,
    ) async {
      final c = await pump(tester);
      final n = c.read(prayerLogComposerProvider.notifier);
      await n.onCaptured('/tmp/a.jpg');
      await n.onCropped(tinyPng);
      await _settle(tester);

      await tester.tap(find.text('Log Asr'));
      await _settle(tester);

      expect(find.text('Confirm'), findsOneWidget);
      expect(find.textContaining('offline'), findsOneWidget);
    });
  });

  group('day view', () {
    Future<List<String?>> pump(
      WidgetTester tester, {
      List<PrayerLog> today = const [],
    }) async {
      _bigScreen(tester);
      final requested = <String?>[];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authSessionProvider.overrideWith(SignedIn.new),
            prayerLogsProvider.overrideWith((ref, date) async {
              requested.add(date);
              return date == null ? today : const <PrayerLog>[];
            }),
            prayerLogsRepositoryProvider.overrideWithValue(ScriptedLogsRepo()),
            currentPrayerProvider.overrideWith(() => FixedCurrent(openState())),
          ],
          child: ScreenUtilInit(
            designSize: const Size(390, 844),
            builder: (_, _) => const MaterialApp(home: PrayerLogsScreen()),
          ),
        ),
      );
      await _settle(tester);
      return requested;
    }

    testWidgets('today is requested without a date; summary and rows', (
      tester,
    ) async {
      final requested = await pump(
        tester,
        today: [
          logOf(PrayerName.fajr, points: 10),
          logOf(PrayerName.asr, id: 'l2'),
        ],
      );
      expect(requested.first, isNull);
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('2 of 5 prayers · 15 points'), findsOneWidget);
      expect(find.text('Not logged'), findsNWidgets(3));
      expect(find.text('+10'), findsOneWidget);
    });

    testWidgets('stepping back asks for an explicit date; forward is capped', (
      tester,
    ) async {
      final requested = await pump(tester);
      final next = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.chevron_right_rounded),
      );
      expect(next.onPressed, isNull, reason: 'cannot go past today');

      await tester.tap(find.byTooltip('Previous day'));
      await _settle(tester);
      expect(find.text('Yesterday'), findsOneWidget);
      expect(requested.last, matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));

      await tester.tap(find.byTooltip('Next day'));
      await _settle(tester);
      expect(find.text('Today'), findsOneWidget);
    });

    testWidgets('Undo appears only while the window is open', (tester) async {
      await pump(
        tester,
        today: [
          logOf(
            PrayerName.fajr,
            id: 'closed',
            endsAt: DateTime.now().subtract(const Duration(minutes: 5)),
          ),
          logOf(PrayerName.asr, id: 'open'),
        ],
      );
      expect(find.text('Undo'), findsOneWidget);
    });
  });
}
