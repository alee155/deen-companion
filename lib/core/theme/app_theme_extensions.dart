import 'package:flutter/material.dart';
import 'app_colors.dart';

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

  static const light = AppThemeExtension(
    background: AppColors.parchment,
    surface: AppColors.surfaceLight,
    border: AppColors.borderWarm,
    inkText: AppColors.inkText,
    textSecondary: AppColors.textSecondary,
    textMuted: AppColors.textMuted,
    heroBackground: AppColors.emeraldInk,
    heroForeground: AppColors.parchment,
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

  static const dark = AppThemeExtension(
    background: AppColors.backgroundDark,
    surface: AppColors.surfaceDark,
    border: AppColors.borderDark,
    inkText: AppColors.textPrimaryDark,
    textSecondary: AppColors.textSecondaryDark,
    textMuted: Color(0xFF8A7C68),
    heroBackground: AppColors.emeraldInkDark,
    heroForeground: AppColors.textPrimaryDark,
    gold: AppColors.gold,
    quranAccent: Color(0xFF8FA872),
    quranAccentBg: Color(0xFF2A3020),
    hadithAccent: Color(0xFFC08A78),
    hadithAccentBg: Color(0xFF3A2420),
    duasAccent: AppColors.gold,
    duasAccentBg: Color(0xFF3A3020),
    hijriAccent: Color(0xFFB8A88C),
    hijriAccentBg: Color(0xFF332C22),
    worshipAccent: Color(0xFFE8A05C),
    worshipAccentBg: Color(0xFF3A2818),
    toolsAccent: Color(0xFFC8875C),
    toolsAccentBg: Color(0xFF382418),
  );

  @override
  AppThemeExtension copyWith() => this; // fields all replaced together via named consts above

  @override
  AppThemeExtension lerp(ThemeExtension<AppThemeExtension>? other, double t) {
    if (other is! AppThemeExtension) return this;
    return t < 0.5 ? this : other;
  }
}

/// context.colors.inkText instead of AppColors.inkText — this is the
/// migration every screen needs, one file at a time.
extension AppThemeContextX on BuildContext {
  AppThemeExtension get colors =>
      Theme.of(this).extension<AppThemeExtension>()!;
}
