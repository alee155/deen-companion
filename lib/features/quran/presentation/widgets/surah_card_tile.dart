import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/motion/motion.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/seal_number_badge.dart';
import '../../domain/entities/surah_summary.dart';

/// One surah row: an ornamental number badge, the English name with its
/// Arabic name alongside it, and the revelation place + verse count below.
/// The whole row is the tap target — it opens the player screen (which
/// starts the recitation and carries the favorite toggle itself), so no
/// per-row icons compete for the tap.
class SurahCardTile extends StatelessWidget {
  final SurahSummary surah;
  final VoidCallback onTap;

  const SurahCardTile({super.key, required this.surah, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return PressScale(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16.r),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 10.h),
            child: Row(
              children: [
                SealNumberBadge(number: surah.number),
                SizedBox(width: 14.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              surah.nameEnglish,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.titleMedium.copyWith(
                                color: AppColors.inkText,
                                fontSize: 18.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          SizedBox(width: 8.w),
                          Text(
                            surah.nameArabic,
                            textDirection: TextDirection.rtl,
                            style: AppTypography.arabicBody.copyWith(
                              fontSize: 18.sp,
                              color: AppColors.emeraldInk,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 4.h),
                      Row(
                        children: [
                          Text(
                            surah.revelationPlace.toUpperCase(),
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(width: 10.w),
                          Container(
                            height: 7.h,
                            width: 7.w,
                            decoration: BoxDecoration(
                              color: AppColors.emeraldInk,
                              shape: BoxShape.circle,
                            ),
                          ),
                          SizedBox(width: 10.w),
                          Text(
                            '${surah.versesCount} Verses',
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 6.w),
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textMuted,
                  size: 22.sp,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
