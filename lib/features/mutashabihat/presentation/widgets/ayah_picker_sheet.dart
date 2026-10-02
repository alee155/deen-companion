import 'package:flutter/material.dart';
import 'package:deen_companion/core/motion/motion.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../quran/domain/entities/surah_summary.dart';

/// A grid of every ayah number in [surah], so looking up a verse is a tap
/// instead of typing a number blind and hoping it's in range.
Future<int?> showAyahPickerSheet(
  BuildContext context, {
  required SurahSummary surah,
}) {
  return showModalBottomSheet<int>(
    sheetAnimationStyle: AppMotion.sheetStyle,
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surfaceLight,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
    ),
    builder: (context) => _AyahPickerContent(surah: surah),
  );
}

class _AyahPickerContent extends StatelessWidget {
  final SurahSummary surah;
  const _AyahPickerContent({required this.surah});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: EdgeInsets.fromLTRB(18.w, 12.h, 18.w, 16.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: AppColors.borderWarm,
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
              ),
              SizedBox(height: 14.h),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          surah.nameEnglish,
                          style: AppTypography.headline.copyWith(
                            fontSize: 16.sp,
                            color: AppColors.inkText,
                          ),
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          'Pick an ayah to look up',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    surah.nameArabic,
                    textDirection: TextDirection.rtl,
                    style: AppTypography.arabicBody.copyWith(
                      fontSize: 20.sp,
                      color: AppColors.emeraldInk,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 14.h),
              Expanded(
                child: GridView.builder(
                  controller: scrollController,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5,
                    mainAxisSpacing: 10.h,
                    crossAxisSpacing: 10.w,
                    childAspectRatio: 1,
                  ),
                  itemCount: surah.versesCount,
                  itemBuilder: (context, index) {
                    final ayah = index + 1;
                    return PressScale(
                      scale: AppMotion.pressScaleSmall,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12.r),
                          onTap: () => Navigator.of(context).pop(ayah),
                          child: Container(
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: AppColors.parchment,
                              borderRadius: BorderRadius.circular(12.r),
                              border: Border.all(color: AppColors.borderWarm),
                            ),
                            child: Text(
                              '$ayah',
                              style: AppTypography.bodyMedium.copyWith(
                                color: AppColors.inkText,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
