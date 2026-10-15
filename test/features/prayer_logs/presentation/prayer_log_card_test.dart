import 'package:deen_companion/core/config/flavor_config.dart';
import 'package:deen_companion/features/auth/presentation/providers/auth_session_provider.dart';
import 'package:deen_companion/features/prayer_logs/domain/current_prayer.dart';
import 'package:deen_companion/features/prayer_logs/domain/prayer_log.dart';
import 'package:deen_companion/features/prayer_logs/presentation/providers/prayer_logs_providers.dart';
import 'package:deen_companion/features/prayer_logs/presentation/widgets/prayer_log_card.dart';
import 'package:deen_companion/features/prayer_times/domain/entities/prayer_times.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '_prayer_log_test_support.dart';

Future<ScriptedLogsRepo> _pump(
  WidgetTester tester, {
  required CurrentPrayerState state,
  List<PrayerLog> today = const [],
  bool signedIn = true,
}) async {
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  final repo = ScriptedLogsRepo();
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(body: PrayerLogCard()),
      ),
      GoRoute(
        path: '/prayer-log/new',
        builder: (_, _) => const Scaffold(body: Text('CAMERA FLOW')),
      ),
      GoRoute(
        path: '/prayer-log',
        builder: (_, _) => const Scaffold(body: Text('DAY VIEW')),
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authSessionProvider.overrideWith(
          signedIn ? SignedIn.new : SignedOut.new,
        ),
        currentPrayerProvider.overrideWith(() => FixedCurrent(state)),
        prayerLogsProvider.overrideWith((ref, date) async => today),
        prayerLogsRepositoryProvider.overrideWithValue(repo),
      ],
      child: ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, _) => MaterialApp.router(routerConfig: router),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  return repo;
}

/// The checklist chip carrying exactly this accessibility label.
Finder _labelled(String label) => find.byWidgetPredicate(
  (w) => w is Semantics && w.properties.label == label,
);

/// Stops the card's 1-second ticker before the test ends.
Future<void> _unmount(WidgetTester tester) =>
    tester.pumpWidget(const SizedBox());

void main() {
  setUpAll(() => FlavorConfig(flavor: Flavor.dev, enableLogging: false));

  testWidgets('open and not logged: shows the prayer, countdown and Log', (
    tester,
  ) async {
    await _pump(tester, state: openState());
    expect(find.text('Asr is open'), findsOneWidget);
    expect(find.textContaining('Ends in 1h'), findsOneWidget);
    expect(find.text('Log Asr'), findsOneWidget);
    expect(find.text('Undo'), findsNothing);
    await _unmount(tester);
  });

  testWidgets('Log opens the camera flow', (tester) async {
    await _pump(tester, state: openState());
    await tester.tap(find.text('Log Asr'));
    await tester.pumpAndSettle();
    expect(find.text('CAMERA FLOW'), findsOneWidget);
    await _unmount(tester);
  });

  testWidgets('logged: checkmark state with Undo while the window is open', (
    tester,
  ) async {
    await _pump(
      tester,
      state: openState(logged: true, logId: 'log-1'),
      today: [logOf(PrayerName.asr)],
    );
    expect(find.text('Asr logged'), findsOneWidget);
    expect(find.text('Undo'), findsOneWidget);
    expect(find.text('Log Asr'), findsNothing);
    await _unmount(tester);
  });

  testWidgets('Undo confirms, then deletes by the server log id', (
    tester,
  ) async {
    final repo = await _pump(
      tester,
      state: openState(logged: true, logId: 'log-1'),
      today: [logOf(PrayerName.asr)],
    );
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(find.text('Remove Asr log?'), findsOneWidget);
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();
    expect(repo.deleted, ['log-1']);
    await _unmount(tester);
  });

  testWidgets('keeping the log deletes nothing', (tester) async {
    final repo = await _pump(
      tester,
      state: openState(logged: true, logId: 'log-1'),
      today: [logOf(PrayerName.asr)],
    );
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Keep'));
    await tester.pumpAndSettle();
    expect(repo.deleted, isEmpty);
    await _unmount(tester);
  });

  testWidgets('no window open: disabled button and the next prayer', (
    tester,
  ) async {
    await _pump(
      tester,
      state: CurrentPrayerState(
        now: DateTime.now(),
        next: NextPrayer(
          prayer: PrayerName.maghrib,
          startsAt: DateTime.now().add(const Duration(hours: 2)),
        ),
      ),
    );
    expect(find.text('No prayer open'), findsOneWidget);
    expect(find.textContaining('Next: Maghrib'), findsOneWidget);
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
    await _unmount(tester);
  });

  testWidgets('times never synced: says so and offers Retry', (tester) async {
    await _pump(tester, state: CurrentPrayerState(now: DateTime.now()));
    expect(find.text('Setting up your prayer times…'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    await _unmount(tester);
  });

  testWidgets('checklist marks the prayers logged today', (tester) async {
    await _pump(
      tester,
      state: openState(),
      today: [
        logOf(PrayerName.fajr),
        logOf(PrayerName.dhuhr, id: 'l2'),
      ],
    );
    expect(_labelled('Fajr logged'), findsOneWidget);
    expect(_labelled('Dhuhr logged'), findsOneWidget);
    expect(_labelled('Asr not logged'), findsOneWidget);
    await _unmount(tester);
  });

  testWidgets('tapping the card opens the day view', (tester) async {
    await _pump(tester, state: openState());
    await tester.tap(find.text('Asr is open'));
    await tester.pumpAndSettle();
    expect(find.text('DAY VIEW'), findsOneWidget);
    await _unmount(tester);
  });

  testWidgets('guests see nothing', (tester) async {
    await _pump(tester, state: openState(), signedIn: false);
    expect(find.text('Asr is open'), findsNothing);
    expect(find.byType(FilledButton), findsNothing);
    await _unmount(tester);
  });
}
