import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/motion/motion.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';

/// A centred icon, title and message, with an optional action — the empty,
/// no-matches and error states of the Favorites screen.
class FavoritesMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const FavoritesMessage({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(36.w, 48.h, 36.w, 0),
      child: Column(
        children: [
          Container(
            height: 88.h,
            width: 88.h,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.emeraldInk.withValues(alpha: 0.12),
            ),
            child: Icon(icon, color: AppColors.emeraldInk, size: 38.sp),
          ).slideIn(RevealDirection.top),
          SizedBox(height: 20.h),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.w800,
              color: AppColors.inkText,
            ),
          ).slideIn(
            RevealDirection.bottom,
            delay: const Duration(milliseconds: 70),
          ),
          SizedBox(height: 8.h),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ).slideIn(
            RevealDirection.bottom,
            delay: const Duration(milliseconds: 130),
          ),
          if (actionLabel != null) ...[
            SizedBox(height: 20.h),
            Pressable(
              onTap: onAction,
              haptic: true,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
                decoration: BoxDecoration(
                  color: AppColors.emeraldInk,
                  borderRadius: BorderRadius.circular(16.r),
                ),
                child: Text(
                  actionLabel!,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onEmeraldInk,
                  ),
                ),
              ),
            ).slideIn(
              RevealDirection.bottom,
              delay: const Duration(milliseconds: 200),
            ),
          ],
        ],
      ),
    );
  }
}
