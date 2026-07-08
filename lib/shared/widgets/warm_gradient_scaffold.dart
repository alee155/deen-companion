import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// The warm cream-to-gold wash from the Qibla screen, made reusable.
/// Reserved for card-focused "moment" screens (Home, Prayer Times, Qibla) —
/// deliberately NOT applied to dense list/form screens (Quran, Hadith, Duas
/// browsing, calculators), since a gradient behind long scrolling text or
/// form fields reduces legibility. Flat AppColors.parchment stays correct there.
class WarmGradientBackground extends StatelessWidget {
  final Widget child;
  const WarmGradientBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
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
