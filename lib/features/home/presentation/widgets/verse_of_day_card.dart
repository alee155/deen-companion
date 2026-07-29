import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';

/// Static for now — wired to a real "verse of the day" source once
/// the Quran feature is integrated. Kept as its own widget so swapping
/// the data source later doesn't touch the home screen layout.
class VerseOfDayCard extends StatelessWidget {
  const VerseOfDayCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 16.h),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.borderWarm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'VERSE OF THE DAY',
            style: AppTypography.caption.copyWith(
              color: AppColors.gold,
              letterSpacing: 0.5,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'وَمَن يَتَّقِ اللَّهَ يَجْعَل لَّهُ مَخْرَجًا',
            textDirection: TextDirection.rtl,
            style: AppTypography.arabicBody.copyWith(color: AppColors.inkText),
          ),
          SizedBox(height: 8.h),
          Text(
            'And whoever fears Allah, He will make for him a way out.',
            style: AppTypography.greetingSerif.copyWith(
              fontSize: 14.sp,
              color: AppColors.inkText,
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            'Surah At-Talaq, 65:2',
            style: AppTypography.caption.copyWith(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}
