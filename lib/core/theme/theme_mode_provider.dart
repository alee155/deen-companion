import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/app_constants.dart';
import '../di/providers.dart';

/// The appearance the user picked: Light, Dark, or Automatic (the look follows
/// the prayer periods of the day). It opens in Light unless the user has chosen
/// otherwise, and there is deliberately no "System" option: the choice is
/// explicit and sticky, and Automatic is only ever on because they turned it on.
enum AppThemeChoice {
  light,
  dark,
  automatic;

  /// Material's mode. Automatic reports light because the real brightness comes
  /// from the active period (see `activeThemeVariantProvider`).
  ThemeMode get themeMode =>
      this == AppThemeChoice.dark ? ThemeMode.dark : ThemeMode.light;

  String get label => switch (this) {
    AppThemeChoice.light => 'Light',
    AppThemeChoice.dark => 'Dark',
    AppThemeChoice.automatic => 'Automatic',
  };

  static AppThemeChoice fromStored(String? value) {
    return switch (value) {
      'dark' => AppThemeChoice.dark,
      'automatic' => AppThemeChoice.automatic,
      _ => AppThemeChoice.light,
    };
  }
}

class ThemeModeNotifier extends Notifier<AppThemeChoice> {
  @override
  AppThemeChoice build() {
    // Storage is already open by the time the first read happens (bootstrap
    // awaits it), so the stored choice can be restored synchronously — no
    // Light-then-Dark flash on launch.
    final stored = ref
        .read(localStorageServiceProvider)
        .get<String>(AppConstants.settingsBoxName, AppConstants.themeModeKey);
    return AppThemeChoice.fromStored(stored);
  }

  Future<void> setChoice(AppThemeChoice choice) async {
    if (choice == state) return;
    state = choice;
    await ref
        .read(localStorageServiceProvider)
        .put(
          AppConstants.settingsBoxName,
          AppConstants.themeModeKey,
          choice.name,
        );
  }

  Future<void> toggle() => setChoice(
    state == AppThemeChoice.dark ? AppThemeChoice.light : AppThemeChoice.dark,
  );
}

final themeModeNotifierProvider =
    NotifierProvider<ThemeModeNotifier, AppThemeChoice>(ThemeModeNotifier.new);
