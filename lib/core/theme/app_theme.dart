import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';
import 'app_theme_extensions.dart';
import 'app_typography.dart';

class AppTheme {
  AppTheme._();

  /// Both themes are built from the same code path, with [AppColors] switched
  /// to the matching palette first — so a Light and a Dark screen differ only
  /// in palette values, never in which widgets got themed.
  static ThemeData light() => _build(Brightness.light);

  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    // Install the palette before reading any AppColors getter below.
    AppColors.applyBrightness(brightness);
    final isDark = brightness == Brightness.dark;

    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: AppColors.emeraldInk,
      onPrimary: AppColors.onEmeraldInk,
      primaryContainer: AppColors.heroSurface,
      onPrimaryContainer: AppColors.onHeroSurface,
      secondary: AppColors.gold,
      onSecondary: isDark ? const Color(0xFF241C0A) : const Color(0xFF241C0A),
      secondaryContainer: AppColors.duasAccentBg,
      onSecondaryContainer: AppColors.duasAccent,
      tertiary: AppColors.amber,
      onTertiary: const Color(0xFF2A1608),
      surface: AppColors.surfaceLight,
      onSurface: AppColors.inkText,
      surfaceContainerHighest: AppColors.parchment,
      onSurfaceVariant: AppColors.textSecondary,
      surfaceTint: Colors.transparent,
      outline: AppColors.borderWarm,
      outlineVariant: AppColors.borderWarm,
      error: AppColors.error,
      onError: isDark ? const Color(0xFF2A0F0B) : Colors.white,
      errorContainer: AppColors.hadithAccentBg,
      onErrorContainer: AppColors.error,
      shadow: AppColors.shadow,
      scrim: Colors.black54,
      inverseSurface: AppColors.inkText,
      onInverseSurface: AppColors.parchment,
    );

    return ThemeData(
      brightness: brightness,
      fontFamily: AppTypography.sansFamily,
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.parchment,
      canvasColor: AppColors.parchment,
      dividerColor: AppColors.borderWarm,
      shadowColor: AppColors.shadow,
      extensions: [AppThemeExtension.forCurrentPalette()],
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        backgroundColor: AppColors.surfaceLight,
        foregroundColor: AppColors.inkText,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: AppColors.inkText, size: 22),
        actionsIconTheme: IconThemeData(color: AppColors.inkText, size: 22),
        titleTextStyle: AppTypography.headline.copyWith(
          color: AppColors.inkText,
          fontSize: 17,
        ),
        systemOverlayStyle: isDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
      ),
      textTheme: TextTheme(
        headlineSmall: AppTypography.headline,
        titleMedium: AppTypography.titleMedium,
        bodyLarge: AppTypography.bodyLarge,
        bodyMedium: AppTypography.bodyMedium,
        labelSmall: AppTypography.caption,
      ).apply(bodyColor: AppColors.inkText, displayColor: AppColors.inkText),
      iconTheme: IconThemeData(color: AppColors.inkText),
      cardTheme: CardThemeData(
        color: AppColors.surfaceLight,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppColors.borderWarm),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.emeraldInk,
          // In Dark the primary lifts to a mid teal, so its label has to go
          // dark to stay legible — hence onEmeraldInk rather than a fixed
          // light colour.
          foregroundColor: AppColors.onEmeraldInk,
          disabledBackgroundColor: AppColors.borderWarm,
          disabledForegroundColor: AppColors.textMuted,
          elevation: 0,
          textStyle: AppTypography.button,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.emeraldInk,
          side: BorderSide(color: AppColors.emeraldInk),
          textStyle: AppTypography.button,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.emeraldInk,
          textStyle: AppTypography.button,
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppColors.surfaceLight,
        selectedItemColor: AppColors.emeraldInk,
        unselectedItemColor: AppColors.textMuted,
        type: BottomNavigationBarType.fixed,
        showUnselectedLabels: true,
        elevation: 0,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: AppColors.surfaceLight,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: AppColors.surfaceLight,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surfaceLight,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: AppTypography.headline.copyWith(
          color: AppColors.inkText,
          fontSize: 16,
        ),
        contentTextStyle: AppTypography.bodyLarge.copyWith(
          color: AppColors.textSecondary,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.heroSurface,
        contentTextStyle: AppTypography.bodyLarge.copyWith(
          color: AppColors.onHeroSurface,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceLight,
        hintStyle: AppTypography.bodyLarge.copyWith(color: AppColors.textMuted),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.borderWarm),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.emeraldInk),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.borderWarm),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.emeraldInk
              : AppColors.surfaceLight,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.emeraldInk.withValues(alpha: 0.35)
              : AppColors.borderWarm,
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: AppColors.emeraldInk,
        textColor: AppColors.inkText,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: AppColors.emeraldInk,
      ),
      dividerTheme: DividerThemeData(color: AppColors.borderWarm, space: 1),
    );
  }
}
