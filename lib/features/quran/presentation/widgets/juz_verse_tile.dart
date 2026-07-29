import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/entities/juz.dart';

class JuzVerseTile extends StatelessWidget {
  final JuzVerse verse;
  const JuzVerseTile({super.key, required this.verse});

  @override
  Widget build(BuildContext context) {
    final translation =
        verse.translations['sahih_international'] ??
        verse.translations.values.first;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 14.h),
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
                  color: AppColors.quranAccentBg,
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Text(
                  '${verse.ayah}',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.emeraldInk,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              SizedBox(width: 8.w),
              Text(
                verse.surahName,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Text(
            verse.arabic,
            textAlign: TextAlign.right,
            textDirection: TextDirection.rtl,
            style: AppTypography.arabicBody.copyWith(
              fontSize: 20.sp,
              color: AppColors.inkText,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            translation,
            style: AppTypography.bodyMedium.copyWith(color: AppColors.inkText),
          ),
        ],
      ),
    );
  }
}
