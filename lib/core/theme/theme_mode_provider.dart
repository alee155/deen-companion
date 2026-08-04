import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/app_constants.dart';
import '../di/providers.dart';

/// The app offers exactly two appearances — Light and Dark — and opens in
/// Light unless the user has chosen otherwise. There is deliberately no
/// "System" option: the choice is explicit and sticky.
enum AppThemeChoice {
  light,
  dark;

  ThemeMode get themeMode =>
      this == AppThemeChoice.dark ? ThemeMode.dark : ThemeMode.light;

  String get label => this == AppThemeChoice.dark ? 'Dark' : 'Light';

  static AppThemeChoice fromStored(String? value) {
    return value == AppThemeChoice.dark.name
        ? AppThemeChoice.dark
        : AppThemeChoice.light;
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
