import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Theme-scoped mirror of the palette, for code that would rather read
/// colours from the widget tree (`context.colors.inkText`) than from the
/// static [AppColors] accessors. Both resolve to the same values — the
/// extension is built from whichever palette [AppColors] currently has
/// installed, so the two can never disagree.
@immutable
class AppThemeExtension extends ThemeExtension<AppThemeExtension> {
  final Color background;
  final Color surface;
  final Color border;
  final Color inkText;
  final Color textSecondary;
  final Color textMuted;
  final Color heroBackground;
  final Color heroForeground;
  final Color gold;
  final Color quranAccent;
  final Color quranAccentBg;
  final Color hadithAccent;
  final Color hadithAccentBg;
  final Color duasAccent;
  final Color duasAccentBg;
  final Color hijriAccent;
  final Color hijriAccentBg;
  final Color worshipAccent;
  final Color worshipAccentBg;
  final Color toolsAccent;
  final Color toolsAccentBg;

  const AppThemeExtension({
    required this.background,
    required this.surface,
    required this.border,
    required this.inkText,
    required this.textSecondary,
    required this.textMuted,
    required this.heroBackground,
    required this.heroForeground,
    required this.gold,
    required this.quranAccent,
    required this.quranAccentBg,
    required this.hadithAccent,
    required this.hadithAccentBg,
    required this.duasAccent,
    required this.duasAccentBg,
    required this.hijriAccent,
    required this.hijriAccentBg,
    required this.worshipAccent,
    required this.worshipAccentBg,
    required this.toolsAccent,
    required this.toolsAccentBg,
  });

  /// Snapshot of the palette for [brightness]. Built eagerly by [AppTheme]
  /// while that brightness is installed, so it never reads a stale palette.
  factory AppThemeExtension.forCurrentPalette() {
    return AppThemeExtension(
      background: AppColors.parchment,
      surface: AppColors.surfaceLight,
      border: AppColors.borderWarm,
      inkText: AppColors.inkText,
      textSecondary: AppColors.textSecondary,
      textMuted: AppColors.textMuted,
      heroBackground: AppColors.heroSurface,
      heroForeground: AppColors.onHeroSurface,
      gold: AppColors.gold,
      quranAccent: AppColors.quranAccent,
      quranAccentBg: AppColors.quranAccentBg,
      hadithAccent: AppColors.hadithAccent,
      hadithAccentBg: AppColors.hadithAccentBg,
      duasAccent: AppColors.duasAccent,
      duasAccentBg: AppColors.duasAccentBg,
      hijriAccent: AppColors.hijriAccent,
      hijriAccentBg: AppColors.hijriAccentBg,
      worshipAccent: AppColors.worshipAccent,
      worshipAccentBg: AppColors.worshipAccentBg,
      toolsAccent: AppColors.toolsAccent,
      toolsAccentBg: AppColors.toolsAccentBg,
    );
  }

  @override
  AppThemeExtension copyWith() => this; // fields are replaced as a whole set

  @override
  AppThemeExtension lerp(ThemeExtension<AppThemeExtension>? other, double t) {
    if (other is! AppThemeExtension) return this;
    return t < 0.5 ? this : other;
  }
}

/// `context.colors.inkText` — equivalent to `AppColors.inkText`, for widgets
/// that prefer resolving colours through the tree.
extension AppThemeContextX on BuildContext {
  AppThemeExtension get colors =>
      Theme.of(this).extension<AppThemeExtension>()!;
}
