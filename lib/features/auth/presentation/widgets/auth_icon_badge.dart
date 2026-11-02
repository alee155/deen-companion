import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/motion/motion.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../splash/presentation/splash_branding.dart';

/// The circular app-logo badge that overlaps the top hero and the form card
/// below it on the auth screens. Place it with [AuthBadgeSlot].
class AuthIconBadge extends StatelessWidget {
  const AuthIconBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 70.h,
      width: 70.h,
      padding: EdgeInsets.all(3.h),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.surfaceLight,
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipOval(
        child: Image.asset(
          SplashBranding.logoAsset,
          fit: BoxFit.cover,
          semanticLabel: 'Deen Companion',
        ),
      ),
    );
  }
}

/// Where the badge sits: straddling the top edge of the form card, half over
/// the hero. It goes in the screen's `Stack`, above the card, and not inside
/// the scrolling form: once the form can scroll, its viewport clips whatever
/// sticks out of it, which cut the badge in half on the taller screens.
class AuthBadgeSlot extends StatelessWidget {
  /// Where the form card starts, from the top of the screen.
  static const double cardTop = 165;

  /// Room the form leaves for the badge, so its first line starts below it.
  static double get formGap => 70.h;

  const AuthBadgeSlot({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: cardTop.h - 35.h,
      left: 24.w,
      child: const AuthIconBadge().slideIn(
        RevealDirection.topStart,
        distance: 18,
      ),
    );
  }
}
