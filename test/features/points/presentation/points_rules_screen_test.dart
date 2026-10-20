import 'package:deen_companion/core/config/flavor_config.dart';
import 'package:deen_companion/core/error/failures.dart';
import 'package:deen_companion/core/usecase/usecase.dart';
import 'package:deen_companion/features/points/domain/entities/points_rule.dart';
import 'package:deen_companion/features/points/presentation/providers/points_providers.dart';
import 'package:deen_companion/features/points/presentation/screens/points_rules_screen.dart';
import 'package:deen_companion/features/points/presentation/widgets/points_chart.dart';
import 'package:deen_companion/shared/widgets/feature_hero.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import '../_points_support.dart';

Future<ProviderContainer> _pump(
  WidgetTester tester,
  FakePointsRepo repo,
) async {
  tester.view.physicalSize = const Size(390 * 3, 1200 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final container = ProviderContainer(
    overrides: [pointsRepositoryProvider.overrideWithValue(repo)],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, _) => const MaterialApp(home: PointsRulesScreen()),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  return container;
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUpAll(() => FlavorConfig(flavor: Flavor.dev, enableLogging: false));

  group('notifier (cache first)', () {
    ProviderContainer make(FakePointsRepo repo) {
      final c = ProviderContainer(
        overrides: [pointsRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(c.dispose);
      return c;
    }

    test('no cache: the server\'s table', () async {
      final repo = FakePointsRepo()..result = Success(sampleRules());
      expect(await make(repo).read(pointsRulesProvider.future), sampleRules());
    });

    test('cache first, then the fresh table if it differs', () async {
      final cached = PointsRules([const PointsRule(prayer: 'fajr', points: 8)]);
      final repo = FakePointsRepo()
        ..cached = cached
        ..result = Success(sampleRules());
      final c = make(repo);
      final seen = <PointsRules>[];
      final sub = c.listen(pointsRulesProvider, (_, n) {
        if (n.hasValue) seen.add(n.value!);
      }, fireImmediately: true);
      addTearDown(sub.close);
      await c.read(pointsRulesProvider.future);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(seen.first, cached);
      expect(seen.last, sampleRules());
    });

    test('an unchanged table is not emitted twice', () async {
      final repo = FakePointsRepo()
        ..cached = sampleRules()
        ..result = Success(sampleRules());
      final c = make(repo);
      final seen = <PointsRules>[];
      final sub = c.listen(pointsRulesProvider, (_, n) {
        if (n.hasValue) seen.add(n.value!);
      }, fireImmediately: true);
      addTearDown(sub.close);
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(seen, hasLength(1));
    });

    test('a failure with a cache keeps showing the cache', () async {
      final repo = FakePointsRepo()..cached = sampleRules();
      final c = make(repo);
      expect(await c.read(pointsRulesProvider.future), sampleRules());
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(c.read(pointsRulesProvider).hasError, isFalse);
    });

    test('a failure with no cache is the error', () async {
      final repo = FakePointsRepo();
      await expectLater(
        make(repo).read(pointsRulesProvider.future),
        throwsA(isA<NetworkFailure>()),
      );
    });

    test('refresh asks the server again', () async {
      final repo = FakePointsRepo()..result = Success(sampleRules());
      final c = make(repo);
      await c.read(pointsRulesProvider.future);
      final before = repo.fetches;
      await c.read(pointsRulesProvider.notifier).refresh();
      expect(repo.fetches, greaterThan(before));
    });
  });

  group('screen', () {
    testWidgets('charts every prayer with its points, Fajr first', (
      tester,
    ) async {
      final repo = FakePointsRepo()..result = Success(sampleRules());
      await _pump(tester, repo);
      await _settle(tester);

      for (final name in ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha']) {
        expect(find.text(name), findsWidgets, reason: name);
      }
      // One value label per bar: 10 for Fajr, 5 for the other four.
      expect(find.text('10'), findsOneWidget);
      expect(find.text('5'), findsNWidgets(4));

      final fajr = tester.getTopLeft(find.text('Fajr').first).dx;
      final isha = tester.getTopLeft(find.text('Isha')).dx;
      expect(fajr, lessThan(isha), reason: 'bars run Fajr to Isha');
    });

    testWidgets('opens with a hero: title, explanation and quick facts', (
      tester,
    ) async {
      final repo = FakePointsRepo()..result = Success(sampleRules());
      await _pump(tester, repo);
      await _settle(tester);
      expect(find.text('Rules'), findsWidgets); // hero title (+ pinned bar)
      expect(
        find.textContaining('Every prayer you log while its time is open'),
        findsOneWidget,
      );
      // 10 is the best any prayer earns; 10 + 5 + 5 + 5 + 5 = 30 for a day.
      expect(find.text('Best: 10 points'), findsOneWidget);
      expect(find.text('Full day: 30 points'), findsOneWidget);
    });

    testWidgets('the hero is the compact kind', (tester) async {
      final repo = FakePointsRepo()..result = Success(sampleRules());
      await _pump(tester, repo);
      await _settle(tester);
      final hero = tester.widget<FeatureHero>(find.byType(FeatureHero));
      expect(hero.compact, isTrue);
    });

    testWidgets('the hero has no facts until the rules are known', (
      tester,
    ) async {
      final repo = FakePointsRepo(); // fails: offline
      await _pump(tester, repo);
      await _settle(tester);
      expect(find.textContaining('Best:'), findsNothing);
      expect(find.textContaining('Full day'), findsNothing);
      expect(
        find.text('Rules'),
        findsWidgets,
        reason: 'the hero is still there',
      );
    });

    testWidgets('puts the chart under a "Points per prayer" heading', (
      tester,
    ) async {
      final repo = FakePointsRepo()..result = Success(sampleRules());
      await _pump(tester, repo);
      await _settle(tester);
      final heading = tester.getTopLeft(find.text('Points per prayer')).dy;
      final chart = tester.getTopLeft(find.byType(PointsChart)).dy;
      expect(heading, lessThan(chart));
    });

    testWidgets('starts on the best prayer and says when it can be logged', (
      tester,
    ) async {
      final repo = FakePointsRepo()..result = Success(sampleRules());
      await _pump(tester, repo);
      await _settle(tester);
      expect(find.text('Log it from Fajr until sunrise'), findsOneWidget);
      expect(find.text('+10 points'), findsOneWidget);
    });

    testWidgets('tapping a bar shows that prayer\'s window and points', (
      tester,
    ) async {
      final repo = FakePointsRepo()..result = Success(sampleRules());
      await _pump(tester, repo);
      await _settle(tester);
      for (final e in {
        'Dhuhr': 'Log it from Dhuhr until Asr',
        'Asr': 'Log it from Asr until Maghrib',
        'Maghrib': 'Log it from Maghrib until Isha',
        'Isha': 'Log it from Isha until the next Fajr',
      }.entries) {
        await tester.tap(find.text(e.key).first);
        await tester.pumpAndSettle();
        expect(find.text(e.value), findsOneWidget, reason: e.key);
        expect(find.text('+5 points'), findsOneWidget);
      }
    });

    testWidgets('a tie for the top starts on the first winner', (tester) async {
      final repo = FakePointsRepo()
        ..result = Success(
          PointsRules([
            const PointsRule(prayer: 'fajr', points: 5),
            const PointsRule(prayer: 'isha', points: 10),
            const PointsRule(prayer: 'asr', points: 10),
          ]),
        );
      await _pump(tester, repo);
      await _settle(tester);
      // Asr comes before Isha in display order.
      expect(find.text('Log it from Asr until Maghrib'), findsOneWidget);
    });

    testWidgets('the best bar is the tallest and the others scale to it', (
      tester,
    ) async {
      final repo = FakePointsRepo()..result = Success(sampleRules());
      await _pump(tester, repo);
      await tester.pumpAndSettle();
      double barHeight(String label) {
        final bar = find.ancestor(
          of: find.text(label).first,
          matching: find.byType(GestureDetector),
        );
        final box = find.descendant(
          of: bar.first,
          matching: find.byType(AnimatedContainer),
        );
        return tester.getSize(box.first).height;
      }

      expect(barHeight('Dhuhr') / barHeight('Fajr'), closeTo(0.5, 0.01));
    });

    testWidgets('explains how points are earned', (tester) async {
      final repo = FakePointsRepo()..result = Success(sampleRules());
      await _pump(tester, repo);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('How it works'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('How it works'), findsOneWidget);
      expect(
        find.text('Log a prayer with a photo while its time is open.'),
        findsOneWidget,
      );
      expect(
        find.text('Each prayer can be logged once a day.'),
        findsOneWidget,
      );
    });

    testWidgets('the explanation is not shown when there are no rules', (
      tester,
    ) async {
      final repo = FakePointsRepo()..result = Success(PointsRules(const []));
      await _pump(tester, repo);
      await _settle(tester);
      expect(find.text('How it works'), findsNothing);
      expect(find.text('Points per prayer'), findsNothing);
    });

    testWidgets('a prayer the app does not know is still listed', (
      tester,
    ) async {
      final repo = FakePointsRepo()
        ..result = Success(
          PointsRules([
            const PointsRule(prayer: 'fajr', points: 10),
            const PointsRule(prayer: 'jumuah', points: 8),
          ]),
        );
      await _pump(tester, repo);
      await _settle(tester);
      expect(find.text('Jumuah'), findsOneWidget);
      expect(find.text('8'), findsOneWidget);
    });

    testWidgets('no rules yet says so', (tester) async {
      final repo = FakePointsRepo()..result = Success(PointsRules(const []));
      await _pump(tester, repo);
      await _settle(tester);
      expect(find.text('No rules have been set yet.'), findsOneWidget);
    });

    testWidgets(
      'shows the cached table straight away while the server answers',
      (tester) async {
        final repo = FakePointsRepo()
          ..cached = sampleRules()
          ..result = Success(sampleRules());
        await _pump(tester, repo);
        expect(find.text('Fajr'), findsOneWidget);
      },
    );

    testWidgets('an error offers Try again, and retrying fetches again', (
      tester,
    ) async {
      final repo = FakePointsRepo(); // fails: offline
      await _pump(tester, repo);
      await _settle(tester);
      expect(find.text('Try again'), findsOneWidget);

      repo.result = Success(sampleRules());
      await tester.tap(find.text('Try again'));
      await _settle(tester);
      expect(find.text('Fajr'), findsOneWidget);
      expect(repo.fetches, greaterThanOrEqualTo(2));
    });
  });
}
