import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';

/// TODO(auth-backend): "Sign in with Google" isn't wired to anything yet —
/// same "leave for now" treatment as email login/signup. The button is
/// built so the real flow can be dropped into [onPressed] later.
class GoogleButton extends StatelessWidget {
  final VoidCallback onPressed;

  const GoogleButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52.h,
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: AppColors.surfaceLight,
          side: BorderSide(color: AppColors.borderWarm, width: 1.w),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30.r),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/google_logo.png',
              height: 20.h,
              width: 20.w,
              errorBuilder: (context, error, stackTrace) => Icon(
                Icons.g_mobiledata,
                size: 24.sp,
                color: AppColors.textSecondary,
              ),
            ),
            SizedBox(width: 10.w),
            Text(
              'Continue with Google',
              style: AppTypography.bodyLarge.copyWith(
                color: AppColors.inkText,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
