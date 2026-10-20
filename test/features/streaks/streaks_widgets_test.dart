import 'package:deen_companion/features/profile/presentation/widgets/profile_streak_card.dart';
import 'package:deen_companion/features/streaks/domain/entities/my_streaks.dart';
import 'package:deen_companion/features/streaks/presentation/providers/streaks_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import '_streaks_support.dart';

Future<void> pump(
  WidgetTester tester,
  Widget child, {
  FakeStreaksRepo? repo,
  double width = 390,
}) async {
  tester.view.physicalSize = Size(width * 3, 1800 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        streaksRepositoryProvider.overrideWithValue(repo ?? FakeStreaksRepo()),
      ],
      child: ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, _) => MaterialApp(
          home: Scaffold(body: SingleChildScrollView(child: child)),
        ),
      ),
    ),
  );
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

void main() {
  group('ProfileStreakCard', () {
    testWidgets('shows the longest current run, best, and each prayer', (
      tester,
    ) async {
      await pump(tester, ProfileStreakCard(streaks: sampleMine()));
      expect(find.text('7'), findsOneWidget);
      expect(find.text('days'), findsOneWidget);
      expect(find.text('20'), findsOneWidget, reason: 'best ever');
      for (final p in ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha']) {
        expect(find.text(p), findsOneWidget, reason: p);
      }
      expect(find.text('12'), findsOneWidget, reason: 'Fajr streak');
      expect(find.text('Longest run right now: Family.'), findsOneWidget);
    });

    testWidgets('with no groups it invites the user to join one', (
      tester,
    ) async {
      await pump(tester, const ProfileStreakCard(streaks: MyStreaks.empty));
      expect(
        find.text('Join a group to start a streak with others.'),
        findsOneWidget,
      );
    });

    testWidgets('with a group but no run it says what to do today', (
      tester,
    ) async {
      await pump(
        tester,
        const ProfileStreakCard(
          streaks: MyStreaks(
            groups: [
              GroupStreakSummary(
                groupId: 'g1',
                name: 'Family',
                currentStreak: 0,
                bestStreak: 4,
                minPrayers: 3,
              ),
            ],
            prayers: {},
          ),
        ),
      );
      expect(
        find.text('Log 3 prayers today to start a streak in Family.'),
        findsOneWidget,
      );
    });

    testWidgets('does not overflow on a narrow phone', (tester) async {
      await pump(tester, ProfileStreakCard(streaks: sampleMine()), width: 320);
      expect(tester.takeException(), isNull);
    });
  });
}
