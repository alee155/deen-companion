import 'package:deen_companion/core/router/app_router.dart';
import 'package:deen_companion/features/prayer_reminders/data/prayer_alarm_channel.dart';
import 'package:deen_companion/features/prayer_reminders/domain/prayer_alarm_launch.dart';
import 'package:deen_companion/features/prayer_reminders/presentation/providers/prayer_alarm_launch_service.dart';
import 'package:deen_companion/features/prayer_reminders/presentation/screens/prayer_alarm_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _FakeChannel extends PrayerAlarmChannel {
  PrayerAlarmLaunch? pending;
  bool snoozeResult = true;
  final snoozes = <({int minutes, String prayer})>[];
  int consumeCalls = 0;

  @override
  Future<PrayerAlarmLaunch?> consumeAlarmOpen() async {
    consumeCalls++;
    final p = pending;
    pending = null;
    return p;
  }

  @override
  Future<bool> snoozeAlarm({
    required int minutes,
    required String prayerName,
    required String label,
  }) async {
    snoozes.add((minutes: minutes, prayer: prayerName));
    return snoozeResult;
  }
}

PrayerAlarmLaunch _launch({int snooze = 10}) => PrayerAlarmLaunch(
  prayerName: 'fajr',
  label: 'Fajr — time to pray',
  time: DateTime(2026, 10, 28, 5, 12),
  snoozeMinutes: snooze,
);

void main() {
  group('PrayerAlarmLaunchService', () {
    late _FakeChannel channel;
    late GoRouter router;
    late List<Object?> pushedExtras;

    ProviderContainer make() {
      pushedExtras = [];
      router = GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, _) => const SizedBox()),
          GoRoute(
            path: '/prayer-alarm',
            builder: (_, state) {
              pushedExtras.add(state.extra);
              return const SizedBox();
            },
          ),
        ],
      );
      final c = ProviderContainer(
        overrides: [
          prayerAlarmChannelProvider.overrideWithValue(channel),
          appRouterProvider.overrideWithValue(router),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    setUp(() => channel = _FakeChannel());

    testWidgets('does nothing off iOS', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      channel.pending = _launch();
      final c = make();

      c.read(prayerAlarmLaunchServiceProvider).start();
      await tester.pump();

      expect(channel.consumeCalls, 0);
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('a cold-start alarm waits for Home, then opens the screen', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      channel.pending = _launch();
      final c = make();
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      final service = c.read(prayerAlarmLaunchServiceProvider);

      service.start();
      await tester.pump();
      expect(pushedExtras, isEmpty, reason: 'the router is not ready yet');

      await service.onHomeReady();
      await tester.pumpAndSettle();

      expect(pushedExtras, hasLength(1));
      expect((pushedExtras.single as PrayerAlarmLaunch).prayerName, 'fajr');
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('an alarm opened while the app is running opens at once', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final c = make();
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      final service = c.read(prayerAlarmLaunchServiceProvider);
      service.start();
      await service.onHomeReady();

      channel.pending = _launch();
      service.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(pushedExtras, hasLength(1));
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('each alarm is opened once', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      channel.pending = _launch();
      final c = make();
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      final service = c.read(prayerAlarmLaunchServiceProvider);
      service.start();
      await service.onHomeReady();
      await service.check();
      await tester.pumpAndSettle();

      expect(pushedExtras, hasLength(1));
      debugDefaultTargetPlatformOverride = null;
    });
  });

  group('PrayerAlarmScreen', () {
    late _FakeChannel channel;

    Future<GoRouter> pump(WidgetTester tester, PrayerAlarmLaunch launch) async {
      channel = _FakeChannel();
      // An iPhone-sized screen (390 x 844), so the layout is the real one.
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, _) => Scaffold(
              body: TextButton(
                onPressed: () => context.push('/prayer-alarm', extra: launch),
                child: const Text('go'),
              ),
            ),
          ),
          GoRoute(
            path: '/prayer-alarm',
            builder: (_, state) =>
                PrayerAlarmScreen(launch: state.extra as PrayerAlarmLaunch),
          ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [prayerAlarmChannelProvider.overrideWithValue(channel)],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pump(); // the route is added…
      await tester.pump(const Duration(milliseconds: 1200)); // …then settles
      return router;
    }

    testWidgets('shows the prayer, its time, the verse and both buttons', (
      tester,
    ) async {
      await pump(tester, _launch());

      expect(find.text('Time to pray'), findsOneWidget);
      expect(find.text('Fajr'), findsOneWidget);
      expect(find.text('5:12 AM'), findsOneWidget);
      expect(find.textContaining('Qur’an 4:103'), findsOneWidget);
      expect(find.text('Dismiss'), findsOneWidget);
      expect(find.text('Snooze 10 min'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('hides Snooze for a prayer that has it switched off', (
      tester,
    ) async {
      await pump(tester, _launch(snooze: 0));

      expect(find.text('Dismiss'), findsOneWidget);
      expect(find.textContaining('Snooze'), findsNothing);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('Dismiss closes the screen without snoozing', (tester) async {
      await pump(tester, _launch());

      await tester.tap(find.text('Dismiss'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1200));

      expect(find.text('Dismiss'), findsNothing);
      expect(find.text('go'), findsOneWidget);
      expect(channel.snoozes, isEmpty);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('Snooze arms another alarm, confirms, and closes', (
      tester,
    ) async {
      await pump(tester, _launch());

      await tester.tap(find.text('Snooze 10 min'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1200));

      expect(channel.snoozes, [(minutes: 10, prayer: 'fajr')]);
      // (the message can be drawn by both pages while the route slides away)
      expect(find.text('Snoozed for 10 minutes'), findsWidgets);
      expect(find.text('Dismiss'), findsNothing);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a failed snooze says so and stays open', (tester) async {
      await pump(tester, _launch());
      channel.snoozeResult = false;

      await tester.tap(find.text('Snooze 10 min'));
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.textContaining('Couldn’t snooze'), findsOneWidget);
      expect(find.text('Dismiss'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });
  });
}
