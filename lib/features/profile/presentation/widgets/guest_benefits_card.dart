import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';

/// Shown to guests: what an account adds, and what stays the same.
class GuestBenefitsCard extends StatelessWidget {
  const GuestBenefitsCard({super.key});

  @override
  Widget build(BuildContext context) {
    Widget row(IconData icon, String title, String body) => Padding(
      padding: EdgeInsets.symmetric(vertical: 8.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38.w,
            height: 38.w,
            decoration: BoxDecoration(
              color: AppColors.worshipAccentBg,
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Icon(icon, size: 19.sp, color: AppColors.worshipAccent),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.inkText,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  body,
                  style: TextStyle(
                    fontSize: 12.sp,
                    height: 1.4,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return Container(
      padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 10.h),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.auto_awesome_rounded,
                size: 16.sp,
                color: AppColors.gold,
              ),
              SizedBox(width: 8.w),
              Text(
                'With an account',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.inkText,
                ),
              ),
            ],
          ),
          SizedBox(height: 6.h),
          row(
            Icons.groups_rounded,
            'Create and join groups',
            'Read the Quran together with family and friends.',
          ),
          row(
            Icons.local_fire_department_rounded,
            'Build a daily streak',
            'Stay consistent and see your progress here.',
          ),
          Divider(height: 20.h, color: AppColors.borderWarm),
          Row(
            children: [
              Icon(
                Icons.lock_outline_rounded,
                size: 15.sp,
                color: AppColors.textMuted,
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  'Favorites, recents and settings stay on this device either way.',
                  style: TextStyle(
                    fontSize: 11.5.sp,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 4.h),
        ],
      ),
    );
  }
}
