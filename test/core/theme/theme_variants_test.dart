import 'dart:math' as math;

import 'package:deen_companion/core/theme/app_colors.dart';
import 'package:deen_companion/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

double _luminance(Color c) {
  double ch(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
}

double contrast(Color a, Color b) {
  final la = _luminance(a), lb = _luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  tearDown(() => AppColors.applyVariant(ThemeVariant.light));

  group('every look passes WCAG AA for text', () {
    for (final v in ThemeVariant.values) {
      test(v.name, () {
        AppColors.applyVariant(v);
        for (final ground in [
          AppColors.parchment,
          AppColors.surfaceLight,
          AppColors.backgroundGradientStart,
          AppColors.backgroundGradientEnd,
        ]) {
          expect(
            contrast(AppColors.inkText, ground),
            greaterThanOrEqualTo(4.5),
          );
          expect(
            contrast(AppColors.textSecondary, ground),
            greaterThanOrEqualTo(4.5),
          );
        }
        // Text on the always-dark hero surface stays readable in every look.
        expect(
          contrast(AppColors.onHeroSurface, AppColors.heroSurface),
          greaterThanOrEqualTo(4.5),
        );
      });
    }
  });

  group('hero gradient', () {
    test('light and dark keep the original ink-to-brand gradient', () {
      for (final v in [ThemeVariant.light, ThemeVariant.dark]) {
        AppColors.applyVariant(v);
        expect(AppColors.heroGradient, [
          AppColors.heroSurface,
          AppColors.emeraldInkDark,
        ]);
      }
    });

    test('every period has its own hero sky', () {
      final seen = <String>{};
      for (final v in ThemeVariant.values.where(
        (v) => v != ThemeVariant.light && v != ThemeVariant.dark,
      )) {
        AppColors.applyVariant(v);
        seen.add(AppColors.heroGradient.map((c) => c.toARGB32()).join('-'));
      }
      expect(seen.length, 6);
    });

    for (final v in ThemeVariant.values) {
      test('hero text stays readable on both stops: ${v.name}', () {
        AppColors.applyVariant(v);
        for (final stop in AppColors.heroGradient) {
          expect(
            contrast(AppColors.onHeroSurface, stop),
            greaterThanOrEqualTo(3.0),
          );
        }
      });
    }
  });

  test('light and dhuhr share a palette; dark and isha differ', () {
    AppColors.applyVariant(ThemeVariant.light);
    final light = AppColors.parchment;
    AppColors.applyVariant(ThemeVariant.dhuhr);
    expect(AppColors.parchment, light);
    AppColors.applyVariant(ThemeVariant.dark);
    final dark = AppColors.parchment;
    AppColors.applyVariant(ThemeVariant.isha);
    expect(AppColors.parchment, isNot(dark));
  });

  test('brand colours stay constant across every period', () {
    AppColors.applyVariant(ThemeVariant.light);
    final brand = AppColors.emeraldInk;
    final hero = AppColors.heroSurface;
    for (final v in [
      ThemeVariant.fajr,
      ThemeVariant.sunrise,
      ThemeVariant.asr,
      ThemeVariant.maghrib,
    ]) {
      AppColors.applyVariant(v);
      expect(AppColors.heroSurface, v.isDark ? isNot(hero) : hero);
      if (!v.isDark) expect(AppColors.emeraldInk, brand);
    }
  });

  // AppTheme's text styles use ScreenUtil, so build inside ScreenUtilInit.
  testWidgets('isDark and brightness agree for every look', (tester) async {
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(375, 812),
        builder: (context, child) {
          for (final v in ThemeVariant.values) {
            final theme = AppTheme.forVariant(v);
            expect(AppColors.isDark, v.isDark, reason: v.name);
            expect(
              theme.brightness,
              v.isDark ? Brightness.dark : Brightness.light,
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  });
}
