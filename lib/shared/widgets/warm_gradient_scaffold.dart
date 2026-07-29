import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme_extensions.dart';

class WarmGradientBackground extends StatelessWidget {
  final Widget child;
  const WarmGradientBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? [AppColors.backgroundDark, AppColors.surfaceDark]
              : [
                  AppColors.backgroundGradientStart,
                  AppColors.backgroundGradientEnd,
                ],
        ),
      ),
      child: child,
    );
  }
}
