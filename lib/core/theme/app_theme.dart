import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_typography.dart';
import 'app_theme_extensions.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get light => _base(Brightness.light).copyWith(
    scaffoldBackgroundColor: AppColors.parchment,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.emeraldInk,
      brightness: Brightness.light,
      surface: AppColors.surfaceLight,
      secondary: AppColors.gold,
    ),
    extensions: const [AppThemeExtension.light],
  );

  static ThemeData get dark => _base(Brightness.dark).copyWith(
    scaffoldBackgroundColor: AppColors.backgroundDark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.emeraldInk,
      brightness: Brightness.dark,
      surface: AppColors.surfaceDark,
      secondary: AppColors.gold,
    ),
    extensions: const [AppThemeExtension.dark],
  );

  static ThemeData _base(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return ThemeData(
      brightness: brightness,
      fontFamily: AppTypography.sansFamily,
      useMaterial3: true,
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: false,
        backgroundColor: isDark
            ? AppColors.surfaceDark
            : AppColors.surfaceLight,
        foregroundColor: isDark ? AppColors.textPrimaryDark : AppColors.inkText,
        surfaceTintColor: Colors.transparent,
      ),
      textTheme:
          TextTheme(
            headlineSmall: AppTypography.headline,
            titleMedium: AppTypography.titleMedium,
            bodyLarge: AppTypography.bodyLarge,
            bodyMedium: AppTypography.bodyMedium,
            labelSmall: AppTypography.caption,
          ).apply(
            bodyColor: isDark ? AppColors.textPrimaryDark : AppColors.inkText,
            displayColor: isDark
                ? AppColors.textPrimaryDark
                : AppColors.inkText,
          ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.emeraldInk,
          foregroundColor: AppColors.parchment,
          textStyle: AppTypography.button,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.gold,
          side: const BorderSide(color: AppColors.gold),
          textStyle: AppTypography.button,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: isDark
            ? AppColors.surfaceDark
            : AppColors.surfaceLight,
        selectedItemColor: AppColors.emeraldInk,
        unselectedItemColor: isDark
            ? AppColors.textSecondaryDark
            : AppColors.textMuted,
        type: BottomNavigationBarType.fixed,
        showUnselectedLabels: true,
        elevation: 0,
      ),
      dividerColor: isDark ? AppColors.borderDark : AppColors.borderWarm,
    );
  }
}
