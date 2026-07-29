import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/mutashabihat_verse_ref.dart';

class MutashabihatBaseVerseCard extends StatelessWidget {
  final MutashabihatVerseRef verse;
  const MutashabihatBaseVerseCard({super.key, required this.verse});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        color: AppColors.quranAccentBg,
        borderRadius: BorderRadius.circular(16.r),
        border: Border(
          left: BorderSide(color: AppColors.quranAccent, width: 4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'THE VERSE',
            style: TextStyle(
              fontSize: 11.sp,
              color: AppColors.quranAccent,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            verse.arabic,
            textDirection: TextDirection.rtl,
            style: TextStyle(
              fontSize: 20.sp,
              color: AppColors.inkText,
              height: 1.9,
            ),
          ),
          SizedBox(height: 10.h),
          Text(
            verse.translation,
            style: TextStyle(
              fontSize: 14.sp,
              color: AppColors.inkText,
              height: 1.5,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            '${verse.surahNameEnglish} ${verse.verseKey}',
            style: TextStyle(fontSize: 12.sp, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
