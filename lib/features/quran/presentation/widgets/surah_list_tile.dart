import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/entities/surah_summary.dart';

class SurahListTile extends StatelessWidget {
  final SurahSummary surah;
  final VoidCallback onTap;
  final VoidCallback onPlayTap;

  const SurahListTile({
    super.key,
    required this.surah,
    required this.onTap,
    required this.onPlayTap,
  });

  @override
  Widget build(BuildContext context) {
    final isMakkah = surah.revelationPlace.toLowerCase() == 'makkah';

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 13.h),
        child: Row(
          children: [
            Container(
              width: 38.w,
              height: 38.w,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.gold, width: 1.5),
              ),
              child: Text(
                '${surah.number}',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.duasAccent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            SizedBox(width: 14.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    surah.nameEnglish,
                    style: AppTypography.titleMedium.copyWith(
                      color: AppColors.inkText,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Row(
                    children: [
                      Text(
                        '${surah.nameTranslation} · ${surah.versesCount} verses',
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      SizedBox(width: 6.w),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 6.w,
                          vertical: 1.h,
                        ),
                        decoration: BoxDecoration(
                          color: isMakkah
                              ? AppColors.duasAccentBg
                              : AppColors.hijriAccentBg,
                          borderRadius: BorderRadius.circular(6.r),
                        ),
                        child: Text(
                          isMakkah ? 'Makkah' : 'Madinah',
                          style: AppTypography.caption.copyWith(
                            color: isMakkah
                                ? AppColors.duasAccent
                                : AppColors.hijriAccent,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: onPlayTap,
              child: Container(
                width: 32.w,
                height: 32.w,
                margin: EdgeInsets.only(right: 8.w),
                decoration: BoxDecoration(
                  color: AppColors.quranAccentBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.play_arrow,
                  color: AppColors.emeraldInk,
                  size: 16.sp,
                ),
              ),
            ),
            // Text(
            //   surah.nameArabic,
            //   textDirection: TextDirection.rtl,
            //   style: AppTypography.arabicBody.copyWith(
            //     fontSize: 19.sp,
            //     color: AppColors.inkText,
            //   ),
            // ),
          ],
        ),
      ),
    );
  }
}
