import 'package:deen_companion/core/constants/app_constants.dart';
import 'package:deen_companion/core/di/providers.dart';
import 'package:deen_companion/core/theme/theme_mode_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fake_storage.dart';

void main() {
  group('AppThemeChoice', () {
    test('fromStored: dark only for "dark", otherwise light', () {
      expect(AppThemeChoice.fromStored('dark'), AppThemeChoice.dark);
      expect(AppThemeChoice.fromStored('light'), AppThemeChoice.light);
      expect(AppThemeChoice.fromStored(null), AppThemeChoice.light);
      expect(AppThemeChoice.fromStored('system'), AppThemeChoice.light);
      expect(AppThemeChoice.fromStored('DARK'), AppThemeChoice.light);
    });

    test('themeMode and label', () {
      expect(AppThemeChoice.dark.themeMode, ThemeMode.dark);
      expect(AppThemeChoice.light.themeMode, ThemeMode.light);
      expect(AppThemeChoice.dark.label, 'Dark');
      expect(AppThemeChoice.light.label, 'Light');
    });
  });

  group('ThemeModeNotifier', () {
    late FakeStorage storage;
    ProviderContainer make() {
      final c = ProviderContainer(
        overrides: [localStorageServiceProvider.overrideWithValue(storage)],
      );
      addTearDown(c.dispose);
      return c;
    }

    setUp(() => storage = FakeStorage());

    test('defaults to light', () {
      expect(make().read(themeModeNotifierProvider), AppThemeChoice.light);
    });

    test('restores stored dark choice synchronously', () {
      storage.boxes[AppConstants.settingsBoxName] = {
        AppConstants.themeModeKey: 'dark',
      };
      expect(make().read(themeModeNotifierProvider), AppThemeChoice.dark);
    });

    test('setChoice updates state and persists', () async {
      final c = make();
      await c
          .read(themeModeNotifierProvider.notifier)
          .setChoice(AppThemeChoice.dark);
      expect(c.read(themeModeNotifierProvider), AppThemeChoice.dark);
      expect(
        storage.get<String>(
          AppConstants.settingsBoxName,
          AppConstants.themeModeKey,
        ),
        'dark',
      );
    });

    test('setting the same choice does not write', () async {
      final c = make();
      await c
          .read(themeModeNotifierProvider.notifier)
          .setChoice(AppThemeChoice.light);
      expect(storage.boxes[AppConstants.settingsBoxName], isNull);
    });

    test('toggle flips back and forth', () async {
      final c = make();
      final n = c.read(themeModeNotifierProvider.notifier);
      await n.toggle();
      expect(c.read(themeModeNotifierProvider), AppThemeChoice.dark);
      await n.toggle();
      expect(c.read(themeModeNotifierProvider), AppThemeChoice.light);
      expect(
        storage.get<String>(
          AppConstants.settingsBoxName,
          AppConstants.themeModeKey,
        ),
        'light',
      );
    });
  });
}
