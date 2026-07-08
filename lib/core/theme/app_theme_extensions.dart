import 'package:flutter/material.dart';
import 'app_colors.dart';

@immutable
class AppThemeExtension extends ThemeExtension<AppThemeExtension> {
  final Color heroBackground;
  final Color heroForeground;
  final Color goldAccent;

  const AppThemeExtension({
    required this.heroBackground,
    required this.heroForeground,
    required this.goldAccent,
  });

  static const light = AppThemeExtension(
    heroBackground: AppColors.emeraldInk,
    heroForeground: AppColors.parchment,
    goldAccent: AppColors.gold,
  );

  static const dark = AppThemeExtension(
    heroBackground: AppColors.emeraldInkDark,
    heroForeground: AppColors.textPrimaryDark,
    goldAccent: AppColors.gold,
  );

  @override
  AppThemeExtension copyWith({
    Color? heroBackground,
    Color? heroForeground,
    Color? goldAccent,
  }) {
    return AppThemeExtension(
      heroBackground: heroBackground ?? this.heroBackground,
      heroForeground: heroForeground ?? this.heroForeground,
      goldAccent: goldAccent ?? this.goldAccent,
    );
  }

  @override
  AppThemeExtension lerp(ThemeExtension<AppThemeExtension>? other, double t) {
    if (other is! AppThemeExtension) return this;
    return AppThemeExtension(
      heroBackground: Color.lerp(heroBackground, other.heroBackground, t)!,
      heroForeground: Color.lerp(heroForeground, other.heroForeground, t)!,
      goldAccent: Color.lerp(goldAccent, other.goldAccent, t)!,
    );
  }
}
