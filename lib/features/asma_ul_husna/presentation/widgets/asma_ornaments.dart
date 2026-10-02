import 'package:flutter/material.dart';
import 'package:deen_companion/core/motion/motion.dart';
import '../../../../core/theme/app_colors.dart';
export '../../../../shared/widgets/islamic_ornaments.dart';

/// Arabic display face already bundled with the app.
const String kAsmaArabicFont = 'AmiriQuran';

/// Tint pair used to give each Name a quiet identity of its own while
/// staying inside the app palette.
class AsmaTint {
  final Color accent;
  final Color bg;
  const AsmaTint(this.accent, this.bg);

  static AsmaTint of(int number) {
    switch (number % 4) {
      case 0:
        return AsmaTint(AppColors.quranAccent, AppColors.quranAccentBg);
      case 1:
        return AsmaTint(AppColors.duasAccent, AppColors.duasAccentBg);
      case 2:
        return AsmaTint(AppColors.hijriAccent, AppColors.hijriAccentBg);
      default:
        return AsmaTint(AppColors.worshipAccent, AppColors.worshipAccentBg);
    }
  }
}

/// App shared-axis route shared by the Asma screens.
Route<T> asmaRoute<T>(WidgetBuilder builder) {
  return PageRouteBuilder<T>(
    transitionDuration: AppMotion.page,
    reverseTransitionDuration: AppMotion.pageReverse,
    pageBuilder: (context, _, _) => builder(context),
    transitionsBuilder: (context, animation, secondary, child) =>
        buildAppTransition(context, animation, secondary, child),
  );
}
