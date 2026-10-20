import 'package:deen_companion/core/error/failures.dart';
import 'package:deen_companion/core/usecase/usecase.dart';
import 'package:deen_companion/features/streaks/presentation/providers/streaks_providers.dart';
import 'package:deen_companion/features/streaks/presentation/widgets/daily_goal_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import '_streaks_support.dart';

Future<void> pump(
  WidgetTester tester,
  FakeStreaksRepo repo, {
  required bool admin,
  double width = 390,
}) async {
  tester.view.physicalSize = Size(width * 3, 1800 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [streaksRepositoryProvider.overrideWithValue(repo)],
      child: ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, _) => MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: DailyGoalSection(groupId: 'g1', isAdmin: admin),
            ),
          ),
        ),
      ),
    ),
  );
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

FilledButton saveButton(WidgetTester tester) =>
    tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Save goal'));

void main() {
  testWidgets('a member sees the goal and cannot change it', (tester) async {
    await pump(tester, FakeStreaksRepo(), admin: false);
    expect(find.text('Daily goal'), findsOneWidget);
    expect(find.text('Log at least 1 prayer a day'), findsOneWidget);
    expect(
      find.textContaining('Only the group admin can change it'),
      findsOneWidget,
    );
    expect(find.text('Save goal'), findsNothing);
    expect(find.bySemanticsLabel('3 prayers a day'), findsNothing);
  });

  testWidgets('the admin sees five choices, with the current one chosen', (
    tester,
  ) async {
    await pump(tester, FakeStreaksRepo(), admin: true);
    expect(find.bySemanticsLabel('1 prayer a day'), findsOneWidget);
    for (final n in [2, 3, 4, 5]) {
      expect(find.bySemanticsLabel('$n prayers a day'), findsOneWidget);
    }
    expect(saveButton(tester).onPressed, isNull, reason: 'nothing changed');
  });

  testWidgets('the admin picks a goal and saves it', (tester) async {
    final repo = FakeStreaksRepo();
    await pump(tester, repo, admin: true);

    await tester.tap(find.bySemanticsLabel('3 prayers a day'));
    await tester.pump();
    expect(saveButton(tester).onPressed, isNotNull);

    await tester.tap(find.text('Save goal'));
    await tester.pumpAndSettle();
    expect(repo.setRuleCalls, [3]);
    expect(find.text('Log at least 3 prayers a day'), findsOneWidget);
    expect(saveButton(tester).onPressed, isNull, reason: 'now saved');
  });

  testWidgets('picking the current value back is not a change', (tester) async {
    await pump(tester, FakeStreaksRepo(), admin: true);
    await tester.tap(find.bySemanticsLabel('4 prayers a day'));
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('1 prayer a day'));
    await tester.pump();
    expect(saveButton(tester).onPressed, isNull);
  });

  testWidgets('a rejected save shows the server message', (tester) async {
    final repo = FakeStreaksRepo()..setRuleFails = true;
    await pump(tester, repo, admin: true);
    await tester.tap(find.bySemanticsLabel('4 prayers a day'));
    await tester.pump();
    await tester.tap(find.text('Save goal'));
    await tester.pumpAndSettle();
    expect(find.text('Only the admin can do this'), findsOneWidget);
  });

  testWidgets('a failed load offers Retry', (tester) async {
    final repo = FakeStreaksRepo()..rule = const Error(NetworkFailure());
    await pump(tester, repo, admin: true);
    expect(find.text('Couldn’t load this group’s daily goal.'), findsOneWidget);
    expect(find.text('Save goal'), findsNothing);

    repo.rule = Success(StreakRuleFixture.rule(2));
    await tester.tap(find.text('Retry'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Log at least 2 prayers a day'), findsOneWidget);
  });

  testWidgets('does not overflow on a narrow phone at large text', (
    tester,
  ) async {
    await pump(tester, FakeStreaksRepo(), admin: true, width: 320);
    expect(tester.takeException(), isNull);
  });
}
