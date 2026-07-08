import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/entities/hadith.dart';

class HadithDetailScreen extends StatelessWidget {
  final Hadith hadith;
  const HadithDetailScreen({super.key, required this.hadith});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.parchment,
      appBar: AppBar(
        title: Text(hadith.collectionName),
        backgroundColor: AppColors.surfaceLight,
        foregroundColor: AppColors.inkText,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 10.w,
                    vertical: 4.h,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.hadithAccentBg,
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Text(
                    'Hadith ${hadith.hadithNumber}',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.hadithAccent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                SizedBox(width: 8.w),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 10.w,
                    vertical: 4.h,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.quranAccentBg,
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Text(
                    hadith.grade,
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.emeraldInk,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 20.h),
            Text(
              hadith.arabic,
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.right,
              style: AppTypography.arabicBody.copyWith(
                fontSize: 20.sp,
                color: AppColors.inkText,
              ),
            ),
            SizedBox(height: 20.h),
            Divider(color: AppColors.borderWarm),
            SizedBox(height: 20.h),
            Text(
              hadith.english,
              style: AppTypography.bodyLarge.copyWith(color: AppColors.inkText),
            ),
          ],
        ),
      ),
    );
  }
}
