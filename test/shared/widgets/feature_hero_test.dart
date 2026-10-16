import 'package:deen_companion/shared/widgets/feature_hero.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

Future<Size> _heroSize(
  WidgetTester tester, {
  required bool compact,
  List<FeatureHeroChip> chips = const [],
  String subtitle = 'A short line about this screen.',
}) async {
  tester.view.physicalSize = const Size(390 * 3, 1200 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, _) => MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: FeatureHero(
              title: 'Rules',
              subtitle: subtitle,
              ghostIcon: Icons.emoji_events_rounded,
              chips: chips,
              compact: compact,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(seconds: 1));
  return tester.getSize(find.byType(FeatureHero));
}

const _chips = [
  FeatureHeroChip(Icons.star_rounded, 'Best: 10 points'),
  FeatureHeroChip(Icons.event_available_rounded, 'Full day: 30 points'),
];

void main() {
  testWidgets('compact is clearly shorter than the default', (tester) async {
    // No chips and a short subtitle, so the comparison is about spacing and
    // type size, not about how the test font wraps text.
    final normal = await _heroSize(tester, compact: false);
    await tester.pumpWidget(const SizedBox());
    final small = await _heroSize(tester, compact: true);
    expect(small.height, lessThan(normal.height));
    expect(small.height, lessThan(normal.height * 0.8));
  });

  testWidgets('compact stays shorter with chips too', (tester) async {
    final normal = await _heroSize(tester, compact: false, chips: _chips);
    await tester.pumpWidget(const SizedBox());
    final small = await _heroSize(tester, compact: true, chips: _chips);
    expect(small.height, lessThan(normal.height));
  });

  testWidgets('the default size is unchanged for the other screens', (
    tester,
  ) async {
    final a = await _heroSize(tester, compact: false);
    await tester.pumpWidget(const SizedBox());
    // `compact` defaults to false, so omitting it must give the same hero.
    tester.view.physicalSize = const Size(390 * 3, 1200 * 3);
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, _) => MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: FeatureHero(
                title: 'Rules',
                subtitle: 'A short line about this screen.',
                ghostIcon: Icons.emoji_events_rounded,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(tester.getSize(find.byType(FeatureHero)).height, a.height);
  });

  testWidgets('compact keeps the title, subtitle and chips', (tester) async {
    await _heroSize(tester, compact: true, chips: _chips);
    expect(find.text('Rules'), findsOneWidget);
    expect(find.text('A short line about this screen.'), findsOneWidget);
    expect(find.text('Best: 10 points'), findsOneWidget);
    expect(find.text('Full day: 30 points'), findsOneWidget);
  });

  testWidgets('compact uses a smaller title', (tester) async {
    await _heroSize(tester, compact: false);
    final big = tester.widget<Text>(find.text('Rules')).style!.fontSize!;
    await tester.pumpWidget(const SizedBox());
    await _heroSize(tester, compact: true);
    final small = tester.widget<Text>(find.text('Rules')).style!.fontSize!;
    expect(small, lessThan(big));
  });

  testWidgets('compact limits a long subtitle to one line', (tester) async {
    await _heroSize(
      tester,
      compact: true,
      subtitle: List.filled(60, 'a long sentence').join(' '),
    );
    final text = tester.widget<Text>(
      find.textContaining('a long sentence').first,
    );
    expect(text.maxLines, 1);
    expect(text.overflow, TextOverflow.ellipsis);
  });

  testWidgets('the default does not clamp the subtitle', (tester) async {
    await _heroSize(tester, compact: false, subtitle: 'x ' * 80);
    final text = tester.widget<Text>(find.textContaining('x x').first);
    expect(text.maxLines, isNull);
  });
}
