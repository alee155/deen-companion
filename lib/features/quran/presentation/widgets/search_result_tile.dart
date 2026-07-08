import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/entities/search_result.dart';

class SearchResultTile extends StatelessWidget {
  final SearchResult result;
  const SearchResultTile({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    return Container(
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
          Text(
            '${result.surahName} · ${result.verseKey}',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.duasAccent,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            result.arabic,
            textAlign: TextAlign.right,
            textDirection: TextDirection.rtl,
            style: AppTypography.arabicBody.copyWith(
              fontSize: 18.sp,
              color: AppColors.inkText,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            result.translation,
            style: AppTypography.bodyMedium.copyWith(color: AppColors.inkText),
          ),
        ],
      ),
    );
  }
}
