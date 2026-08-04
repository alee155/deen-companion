import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// The app-wide page wash. The gradient stops are palette values now, so
/// this no longer has to branch on brightness itself — Light gets parchment,
/// Dark gets the ink-green ground, from the same two names.
class WarmGradientBackground extends StatelessWidget {
  final Widget child;
  const WarmGradientBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.backgroundGradientStart,
            AppColors.backgroundGradientEnd,
          ],
        ),
      ),
      child: child,
    );
  }
}
