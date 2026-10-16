import 'package:deen_companion/core/config/flavor_config.dart';
import 'package:deen_companion/core/error/failures.dart';
import 'package:deen_companion/core/usecase/usecase.dart';
import 'package:deen_companion/features/points/domain/entities/points_rule.dart';
import 'package:deen_companion/features/points/presentation/providers/points_providers.dart';
import 'package:deen_companion/features/points/presentation/screens/points_rules_screen.dart';
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
    testWidgets('shows every prayer with its points, Fajr first', (
      tester,
    ) async {
      final repo = FakePointsRepo()..result = Success(sampleRules());
      await _pump(tester, repo);
      await _settle(tester);

      for (final name in ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha']) {
        expect(find.text(name), findsOneWidget, reason: name);
      }
      expect(find.text('+10'), findsOneWidget);
      expect(find.text('+5'), findsNWidgets(4));
      expect(find.text('points'), findsNWidgets(5));

      final fajr = tester.getTopLeft(find.text('Fajr')).dy;
      final isha = tester.getTopLeft(find.text('Isha')).dy;
      expect(fajr, lessThan(isha));
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

    testWidgets('lists the prayers under a "Points per prayer" heading', (
      tester,
    ) async {
      final repo = FakePointsRepo()..result = Success(sampleRules());
      await _pump(tester, repo);
      await _settle(tester);
      final heading = tester.getTopLeft(find.text('Points per prayer')).dy;
      final fajr = tester.getTopLeft(find.text('Fajr')).dy;
      expect(heading, lessThan(fajr));
    });

    testWidgets('each card says when the prayer can be logged', (tester) async {
      final repo = FakePointsRepo()..result = Success(sampleRules());
      await _pump(tester, repo);
      await _settle(tester);
      expect(find.text('Log it from Fajr until sunrise'), findsOneWidget);
      expect(find.text('Log it from Dhuhr until Asr'), findsOneWidget);
      expect(find.text('Log it from Asr until Maghrib'), findsOneWidget);
      expect(find.text('Log it from Maghrib until Isha'), findsOneWidget);
      expect(find.text('Log it from Isha until the next Fajr'), findsOneWidget);
    });

    testWidgets('only the best-earning prayer wears the HIGHEST badge', (
      tester,
    ) async {
      final repo = FakePointsRepo()..result = Success(sampleRules());
      await _pump(tester, repo);
      await _settle(tester);
      expect(find.text('HIGHEST'), findsOneWidget);
      final badge = tester.getTopLeft(find.text('HIGHEST')).dy;
      final fajr = tester.getTopLeft(find.text('Fajr')).dy;
      final dhuhr = tester.getTopLeft(find.text('Dhuhr')).dy;
      expect((badge - fajr).abs(), lessThan(10), reason: 'on the Fajr card');
      expect(badge, lessThan(dhuhr));
    });

    testWidgets('a tie for the top gives every winner the badge', (
      tester,
    ) async {
      final repo = FakePointsRepo()
        ..result = Success(
          PointsRules([
            const PointsRule(prayer: 'fajr', points: 10),
            const PointsRule(prayer: 'isha', points: 10),
            const PointsRule(prayer: 'asr', points: 5),
          ]),
        );
      await _pump(tester, repo);
      await _settle(tester);
      expect(find.text('HIGHEST'), findsNWidgets(2));
    });

    testWidgets('each bar shows its share of the best prayer', (tester) async {
      final repo = FakePointsRepo()..result = Success(sampleRules());
      await _pump(tester, repo);
      await tester.pumpAndSettle();
      final factors =
          tester
              .widgetList<FractionallySizedBox>(
                find.byType(FractionallySizedBox),
              )
              .map((w) => w.widthFactor!)
              .toList()
            ..sort();
      // Fajr 10/10 = full; the four 5-point prayers are half.
      expect(factors, [0.5, 0.5, 0.5, 0.5, 1.0]);
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

    testWidgets('the best-earning prayer is outlined in gold', (tester) async {
      final repo = FakePointsRepo()..result = Success(sampleRules());
      await _pump(tester, repo);
      await _settle(tester);

      // A card with the thick (gold) outline.
      final highlighted = find.byWidgetPredicate((w) {
        if (w is! Container) return false;
        final d = w.decoration;
        if (d is! BoxDecoration || d.border is! Border) return false;
        return (d.border! as Border).top.width > 1.2;
      });
      expect(
        find.ancestor(of: find.text('Fajr'), matching: highlighted),
        findsOneWidget,
      );
      expect(
        find.ancestor(of: find.text('Asr'), matching: highlighted),
        findsNothing,
      );
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
      expect(find.text('+8'), findsOneWidget);
    });

    testWidgets('one point reads "point", not "points"', (tester) async {
      final repo = FakePointsRepo()
        ..result = Success(
          PointsRules([const PointsRule(prayer: 'fajr', points: 1)]),
        );
      await _pump(tester, repo);
      await _settle(tester);
      expect(find.text('point'), findsOneWidget);
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
