import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../splash/presentation/splash_branding.dart';

/// The circular app-logo badge that overlaps the top header image and the
/// form card below it on the auth screens.
class AuthIconBadge extends StatelessWidget {
  const AuthIconBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: Offset(0, -35.h),
      child: Container(
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
      ),
    );
  }
}
