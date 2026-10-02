import 'package:flutter/material.dart';
import 'package:deen_companion/core/motion/motion.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';

/// Shows a native-feeling rationale sheet *before* the OS permission dialog
/// — the modern, contextual pattern this app now uses in place of the old
/// upfront permissions gate. Returns true only if the user tapped the
/// action button; it's the caller's job to then trigger the actual OS
/// prompt via the relevant permission service.
Future<bool> showPermissionRequestSheet(
  BuildContext context, {
  required IconData icon,
  required String title,
  required String rationale,
  required String actionLabel,
  Color? accent,
}) async {
  final result = await showModalBottomSheet<bool>(
    sheetAnimationStyle: AppMotion.sheetStyle,
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surfaceLight,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
    ),
    builder: (context) {
      final color = accent ?? AppColors.emeraldInk;
      return Padding(
        padding: EdgeInsets.fromLTRB(
          24.w,
          20.h,
          24.w,
          24.h + MediaQuery.of(context).padding.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: AppColors.borderWarm,
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
            ),
            SizedBox(height: 20.h),
            Center(
              child: Container(
                width: 56.w,
                height: 56.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.12),
                ),
                child: Icon(icon, color: color, size: 28.sp),
              ),
            ),
            SizedBox(height: 16.h),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTypography.headline.copyWith(
                color: AppColors.inkText,
                fontSize: 18.sp,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              rationale,
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            SizedBox(height: 24.h),
            SizedBox(
              height: 50.h,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.emeraldInk,
                  foregroundColor: AppColors.onEmeraldInk,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(26.r),
                  ),
                ),
                child: Text(actionLabel),
              ),
            ),
            SizedBox(height: 8.h),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Not now',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
  return result ?? false;
}
