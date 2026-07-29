import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/entities/hadith.dart';

class HadithCardTile extends StatelessWidget {
  final Hadith hadith;
  final VoidCallback onTap;

  const HadithCardTile({super.key, required this.hadith, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 20.w, vertical: 6.h),
        padding: EdgeInsets.all(14.w),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(color: AppColors.borderWarm),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 26.w,
                  height: 26.w,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.hadithAccentBg,
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Text(
                    '${hadith.hadithNumber}',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.hadithAccent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    hadith.collectionName,
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 2.h),
                  decoration: BoxDecoration(
                    color: AppColors.quranAccentBg,
                    borderRadius: BorderRadius.circular(6.r),
                  ),
                  child: Text(
                    hadith.grade,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.emeraldInk,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 10.h),
            Text(
              hadith.english,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.bodyLarge.copyWith(color: AppColors.inkText),
            ),
          ],
        ),
      ),
    );
  }
}
