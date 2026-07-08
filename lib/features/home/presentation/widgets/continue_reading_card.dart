import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';

class ContinueReadingCard extends StatelessWidget {
  final VoidCallback onTap;
  const ContinueReadingCard({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(color: AppColors.borderWarm),
        ),
        child: Row(
          children: [
            Container(
              width: 36.w,
              height: 36.w,
              decoration: BoxDecoration(
                color: AppColors.quranAccentBg,
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Icon(
                Icons.bookmark_outline,
                color: AppColors.quranAccent,
                size: 16.sp,
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Continue reading',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  SizedBox(height: 1.h),
                  Text(
                    'Surah Al-Kahf, ayah 12',
                    style: AppTypography.titleMedium.copyWith(
                      color: AppColors.inkText,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: AppColors.textMuted, size: 16.sp),
          ],
        ),
      ),
    );
  }
}
