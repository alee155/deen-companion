import 'package:deen_companion/core/theme/app_colors.dart';
import 'package:deen_companion/features/groups/presentation/widgets/group_sheet_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(WidgetTester tester, {bool destructive = false}) =>
    tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(375, 812),
        builder: (_, _) => MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: GroupSheetFrame(
                icon: Icons.group_rounded,
                title: 'Title',
                subtitle: 'Sub',
                destructive: destructive,
                child: const SizedBox(height: 10),
              ),
            ),
          ),
        ),
      ),
    );

LinearGradient _headerGradient(WidgetTester tester) {
  final box = tester
      .widgetList<Container>(find.byType(Container))
      .map((c) => c.decoration)
      .whereType<BoxDecoration>()
      .firstWhere((d) => d.gradient is LinearGradient);
  return box.gradient! as LinearGradient;
}

void main() {
  tearDown(() => AppColors.applyVariant(ThemeVariant.light));

  // Automatic mode: every prayer period has its own header gradient.
  for (final variant in ThemeVariant.values) {
    testWidgets('sheet header gradient follows the ${variant.name} look', (
      tester,
    ) async {
      AppColors.applyVariant(variant);
      await _pump(tester);
      expect(_headerGradient(tester).colors, AppColors.heroGradient);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('a destructive sheet still tints the current look red', (
    tester,
  ) async {
    AppColors.applyVariant(ThemeVariant.maghrib);
    await _pump(tester, destructive: true);
    final colors = _headerGradient(tester).colors;
    expect(colors, isNot(AppColors.heroGradient));
    expect(
      colors[0],
      Color.lerp(AppColors.heroGradient[0], AppColors.error, 0.62),
    );
    await tester.pumpWidget(const SizedBox());
  });
}
