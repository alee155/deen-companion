// Replaces the Flutter counter-app template test that shipped with the
// project (it referenced a `MyApp` class this app never had, so it failed to
// even compile). These cover the two pieces of behaviour most easily broken
// by a careless edit: the Light/Dark palette switch, and the mapping from a
// location problem to the prompt shown for it.

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:deen_companion/core/location/location_status.dart';
import 'package:deen_companion/core/theme/app_colors.dart';
import 'package:deen_companion/core/theme/app_theme.dart';
import 'package:deen_companion/core/theme/theme_mode_provider.dart';

void main() {
  group('AppThemeChoice', () {
    test('defaults to Light when nothing has been stored', () {
      expect(AppThemeChoice.fromStored(null), AppThemeChoice.light);
      expect(AppThemeChoice.fromStored('system'), AppThemeChoice.light);
    });

    test('restores a stored Dark choice', () {
      expect(AppThemeChoice.fromStored('dark'), AppThemeChoice.dark);
    });

    test('maps to a concrete ThemeMode, never system', () {
      expect(AppThemeChoice.light.themeMode, ThemeMode.light);
      expect(AppThemeChoice.dark.themeMode, ThemeMode.dark);
    });
  });

  group('AppColors palette', () {
    tearDown(() => AppColors.applyBrightness(Brightness.light));

    test('switches every neutral when brightness changes', () {
      AppColors.applyBrightness(Brightness.light);
      final lightPage = AppColors.parchment;
      final lightInk = AppColors.inkText;

      AppColors.applyBrightness(Brightness.dark);
      expect(AppColors.isDark, isTrue);
      expect(AppColors.parchment, isNot(lightPage));
      expect(AppColors.inkText, isNot(lightInk));

      // Dark page ground must actually be darker than its text.
      expect(
        AppColors.parchment.computeLuminance(),
        lessThan(AppColors.inkText.computeLuminance()),
      );
    });

    // AppTheme's text styles are sized with ScreenUtil, so building one needs
    // ScreenUtilInit to have run — which is exactly why the app builds its
    // themes inside that builder rather than above it.
    testWidgets('building a theme leaves that theme\'s palette installed', (
      tester,
    ) async {
      await tester.pumpWidget(
        ScreenUtilInit(
          designSize: const Size(375, 812),
          builder: (context, child) {
            AppTheme.dark();
            expect(AppColors.isDark, isTrue);
            AppTheme.light();
            expect(AppColors.isDark, isFalse);
            return const SizedBox.shrink();
          },
        ),
      );
    });

    test('hero surface keeps a light foreground in both themes', () {
      for (final brightness in [Brightness.light, Brightness.dark]) {
        AppColors.applyBrightness(brightness);
        expect(
          AppColors.onHeroSurface.computeLuminance(),
          greaterThan(AppColors.heroSurface.computeLuminance()),
          reason: 'hero text must be lighter than the hero surface',
        );
      }
    });
  });

  group('LocationErrorKind', () {
    test('routes a disabled service to system settings, not a prompt', () {
      expect(LocationErrorKind.serviceDisabled.needsSystemSettings, isTrue);
      expect(LocationErrorKind.serviceDisabled.isRequestable, isFalse);
    });

    test('routes a soft denial to an in-app prompt', () {
      expect(LocationErrorKind.permissionDenied.isRequestable, isTrue);
      expect(LocationErrorKind.permissionDenied.needsSystemSettings, isFalse);
    });

    test('never describes a location problem as being offline', () {
      for (final kind in LocationErrorKind.values) {
        expect(kind.userMessage.toLowerCase(), isNot(contains('offline')));
        expect(kind.userMessage, isNotEmpty);
        expect(kind.actionLabel, isNotEmpty);
      }
    });
  });

  group('LocationAvailability', () {
    test('reports the service problem before the permission problem', () {
      const availability = LocationAvailability(
        serviceEnabled: false,
        hasPermission: false,
        permanentlyDenied: true,
      );
      expect(availability.isUsable, isFalse);
      expect(availability.errorKind, LocationErrorKind.serviceDisabled);
    });

    test('has no error once service and permission are both in place', () {
      const availability = LocationAvailability(
        serviceEnabled: true,
        hasPermission: true,
        permanentlyDenied: false,
      );
      expect(availability.isUsable, isTrue);
      expect(availability.errorKind, isNull);
    });
  });
}
