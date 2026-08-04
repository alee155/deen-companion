import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/entities/hadith.dart';
import '../../domain/hadith_grade.dart';

/// A hadith in a list — search results, favourites. A *preview*, so the text
/// is deliberately clipped to three lines here; the full text lives on the
/// reading screen this tile opens.
class HadithCardTile extends StatelessWidget {
  final Hadith hadith;
  final VoidCallback onTap;

  const HadithCardTile({super.key, required this.hadith, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 5.h),
      child: Material(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(16.r),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16.r),
          child: Container(
            padding: EdgeInsets.all(14.w),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(color: AppColors.borderWarm),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 28.w,
                      height: 28.w,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.hadithAccentBg,
                        borderRadius: BorderRadius.circular(9.r),
                      ),
                      child: Text(
                        '${hadith.hadithNumber}',
                        maxLines: 1,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.hadithAccent,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: Text(
                        hadith.collectionName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.titleMedium.copyWith(
                          color: AppColors.inkText,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    SizedBox(width: 8.w),
                    _GradePill(grade: hadith.gradeLevel, raw: hadith.grade),
                  ],
                ),
                SizedBox(height: 10.h),
                if (hadith.hasTranslation)
                  Text(
                    hadith.english,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodyLarge.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.55,
                    ),
                  )
                else if (hadith.hasArabic)
                  // No translation in the source for this entry — preview the
                  // Arabic rather than showing an empty tile.
                  Text(
                    hadith.arabic,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textDirection: TextDirection.rtl,
                    textAlign: TextAlign.right,
                    style: AppTypography.arabicBody.copyWith(
                      fontSize: 15.sp,
                      height: 1.9,
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GradePill extends StatelessWidget {
  final HadithGrade grade;
  final String raw;

  const _GradePill({required this.grade, required this.raw});

  @override
  Widget build(BuildContext context) {
    // The old tile always painted the grade in "authentic" green, whatever it
    // actually said — a weak narration read as a strong one at a glance.
    final color = switch (grade) {
      HadithGrade.sahih => AppColors.success,
      HadithGrade.hasan => AppColors.duasAccent,
      HadithGrade.daif => AppColors.error,
      HadithGrade.unknown => AppColors.textMuted,
    };
    final label = raw.trim().isEmpty ? grade.label : raw.trim();

    return Container(
      constraints: BoxConstraints(maxWidth: 96.w),
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTypography.caption.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
