import 'package:deen_companion/core/connectivity/presentation/providers/connectivity_banner_provider.dart';
import 'package:deen_companion/core/connectivity/presentation/providers/connectivity_providers.dart';
import 'package:deen_companion/core/connectivity/presentation/widgets/connectivity_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '_connectivity_support.dart';

/// An iPhone with a Dynamic Island: 59 points of status bar to keep clear.
const _safeTop = 59.0;

class _Rig {
  final FakeConnectivitySource source;
  final FakeProbe probe;
  final ProviderContainer container;
  double? appTopPadding;
  _Rig(this.source, this.probe, this.container);

  void goOffline() {
    probe.reachable = false;
    final n = container.read(connectivityProvider.notifier);
    n.reportUnreachable();
    n.reportUnreachable();
  }
}

Future<_Rig> _pump(
  WidgetTester tester, {
  bool reduceMotion = false,
  double textScale = 1.0,
}) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  final source = FakeConnectivitySource();
  final probe = FakeProbe();
  final container = connectivityContainer(source, probe);
  addTearDown(container.dispose);
  final rig = _Rig(source, probe, container);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            padding: const EdgeInsets.only(top: _safeTop),
            viewPadding: const EdgeInsets.only(top: _safeTop),
            disableAnimations: reduceMotion,
            textScaler: TextScaler.linear(textScale),
          ),
          child: ConnectivityBanner(child: child!),
        ),
        home: Builder(
          builder: (context) {
            rig.appTopPadding = MediaQuery.paddingOf(context).top;
            return const Scaffold(body: SafeArea(child: Text('app content')));
          },
        ),
      ),
    ),
  );
  await tester.pump();
  return rig;
}

Future<void> _slide(WidgetTester tester) async {
  await tester.pump(); // the state change
  await tester.pump(const Duration(milliseconds: 400)); // the slide
}

void main() {
  testWidgets('hidden while online: the app owns the whole screen', (
    tester,
  ) async {
    final rig = await _pump(tester);

    expect(find.byType(InkWell), findsNothing);
    expect(rig.appTopPadding, _safeTop);
    expect(
      tester.getTopLeft(find.text('app content')).dy,
      lessThan(_safeTop + 40),
    );

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'offline: the strip fills the status bar and pushes the app down',
    (tester) async {
      final rig = await _pump(tester);
      final before = tester.getTopLeft(find.text('app content')).dy;

      rig.goOffline();
      await tester.pump();
      await tester.pump(); // the probe answers
      await _slide(tester);

      expect(
        find.text('Can’t reach the internet · saved content'),
        findsOneWidget,
      );

      // The strip covers the status bar (so nothing is hidden behind it) and the
      // app, now told the status bar is handled, no longer pads for it.
      final strip = tester.getRect(find.byType(InkWell));
      expect(strip.top, 0);
      expect(strip.height, _safeTop + ConnectivityBanner.bodyHeight);
      expect(rig.appTopPadding, 0);

      // Net effect: content moves down by the strip's body, not by the whole
      // strip (the status-bar padding it used to add is now inside the strip).
      final after = tester.getTopLeft(find.text('app content')).dy;
      expect(after - before, closeTo(ConnectivityBanner.bodyHeight, 0.5));

      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('the app glides rather than jumps while the strip slides in', (
    tester,
  ) async {
    final rig = await _pump(tester);
    rig.goOffline();
    await tester.pump();
    await tester.pump();

    final positions = <double>[];
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 40));
      positions.add(tester.getTopLeft(find.text('app content')).dy);
    }

    for (var i = 1; i < positions.length; i++) {
      expect(
        positions[i],
        greaterThanOrEqualTo(positions[i - 1] - 0.01),
        reason: 'content never moves up on the way down: $positions',
      );
    }
    expect(positions.last - positions.first, greaterThan(5));

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a phone with no network says so differently', (tester) async {
    final rig = await _pump(tester);

    rig.source.set(false);
    await tester.pump();
    await tester.pump(ConnectivityNotifier.offlineDelay);
    await _slide(tester);

    expect(find.text('You’re offline · showing saved content'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('tapping the strip checks again, and finding the net says so', (
    tester,
  ) async {
    final rig = await _pump(tester);
    rig.goOffline();
    await tester.pump();
    await tester.pump();
    await _slide(tester);
    final callsBefore = rig.probe.calls;

    rig.probe.reachable = true;
    await tester.tap(find.byType(InkWell));
    await tester.pump();
    await tester.pump();

    expect(rig.probe.calls, callsBefore + 1);
    await _slide(tester);
    expect(find.text('Back online'), findsOneWidget);

    await tester.pump(ConnectivityBannerNotifier.restoredFor);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('"Back online" leaves by itself and hands the status bar back', (
    tester,
  ) async {
    final rig = await _pump(tester);
    rig.goOffline();
    await tester.pump();
    await tester.pump();
    await _slide(tester);

    rig.container.read(connectivityProvider.notifier).reportReachable();
    await _slide(tester);
    expect(find.text('Back online'), findsOneWidget);

    await tester.pump(ConnectivityBannerNotifier.restoredFor);
    await _slide(tester);

    expect(find.text('Back online'), findsNothing);
    expect(find.byType(InkWell), findsNothing);
    expect(rig.appTopPadding, _safeTop);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('"Back online" is not tappable', (tester) async {
    final rig = await _pump(tester);
    rig.goOffline();
    await tester.pump();
    await tester.pump();
    await _slide(tester);
    rig.container.read(connectivityProvider.notifier).reportReachable();
    await _slide(tester);
    final calls = rig.probe.calls;

    await tester.tap(find.text('Back online'));
    await tester.pump();

    expect(rig.probe.calls, calls);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(ConnectivityBannerNotifier.restoredFor);
  });

  testWidgets('with reduced motion it appears at once, without a slide', (
    tester,
  ) async {
    final rig = await _pump(tester, reduceMotion: true);
    rig.goOffline();
    await tester.pump();
    await tester.pump();
    await tester.pump(); // one frame

    expect(find.byType(InkWell), findsOneWidget);
    expect(rig.appTopPadding, 0);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('the message is announced to screen readers and is a button', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final rig = await _pump(tester);
    rig.goOffline();
    await tester.pump();
    await tester.pump();
    await _slide(tester);

    final node = tester.getSemantics(
      find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.liveRegion == true,
      ),
    );
    expect(node.label, 'Can’t reach the internet · saved content');
    expect(node.flagsCollection.isLiveRegion, isTrue);
    expect(node.flagsCollection.isButton, isTrue);

    handle.dispose();
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a very large system font does not overflow the strip', (
    tester,
  ) async {
    final rig = await _pump(tester, textScale: 2.5);
    rig.goOffline();
    await tester.pump();
    await tester.pump();
    await _slide(tester);

    expect(tester.takeException(), isNull);
    expect(
      tester.getRect(find.byType(InkWell)).height,
      _safeTop + ConnectivityBanner.bodyHeight,
    );

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('works on Android: a status bar of a different height', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final source = FakeConnectivitySource();
    final probe = FakeProbe(reachable: false);
    final container = connectivityContainer(source, probe);
    addTearDown(container.dispose);
    double? pad;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              padding: const EdgeInsets.only(top: 24),
              viewPadding: const EdgeInsets.only(top: 24),
            ),
            child: ConnectivityBanner(child: child!),
          ),
          home: Builder(
            builder: (context) {
              pad = MediaQuery.paddingOf(context).top;
              return const Scaffold(body: SafeArea(child: Text('app content')));
            },
          ),
        ),
      ),
    );
    final n = container.read(connectivityProvider.notifier);
    n.reportUnreachable();
    n.reportUnreachable();
    await tester.pump();
    await tester.pump();
    await _slide(tester);

    expect(
      tester.getRect(find.byType(InkWell)).height,
      24 + ConnectivityBanner.bodyHeight,
    );
    expect(pad, 0);

    await tester.pumpWidget(const SizedBox());
  });
}
