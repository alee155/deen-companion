import 'package:deen_companion/features/points/domain/entities/points_rule.dart';
import 'package:deen_companion/features/points/presentation/widgets/points_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

PointsRules table(List<int> points) => PointsRules([
  for (final (i, p) in points.indexed)
    PointsRule(
      prayer: ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha'][i],
      points: p,
    ),
]);

Future<void> pump(
  WidgetTester tester,
  PointsRules t, {
  Size size = const Size(1080, 2340),
  double ratio = 3,
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = ratio;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: ScreenUtilInit(
        designSize: const Size(375, 812),
        minTextAdapt: true,
        builder: (_, _) => MaterialApp(
          home: Scaffold(
            body: Center(child: PointsChart(table: t)),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  // An overflow is reported as a test exception, so reaching the end passes.
  for (final scale in [0.8, 1.0, 1.3, 1.6, 2.0]) {
    testWidgets('no overflow at text scale $scale', (tester) async {
      await pump(tester, table([10, 5, 5, 5, 5]), textScale: scale);
      final e = tester.takeException();
      expect(e, isNull, reason: e is FlutterError ? e.toStringDeep() : '$e');
    });
  }

  testWidgets('no overflow on a small, dense screen', (tester) async {
    await pump(
      tester,
      table([10, 5, 5, 5, 5]),
      size: const Size(720, 1280),
      ratio: 2.5,
      textScale: 1.3,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('all-zero and single-prayer tables do not overflow', (
    tester,
  ) async {
    await pump(tester, table([0, 0, 0, 0, 0]));
    expect(tester.takeException(), isNull);
    await pump(tester, table([7]));
    expect(tester.takeException(), isNull);
  });
}
