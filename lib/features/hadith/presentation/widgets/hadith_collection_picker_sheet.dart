import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/entities/hadith_collection.dart';

/// Switches the book being read, without a trip back to the library.
/// Returns the chosen collection key, or null if dismissed.
Future<String?> showHadithCollectionPicker(
  BuildContext context, {
  required List<HadithCollection> collections,
  required String selectedKey,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surfaceLight,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
    ),
    builder: (context) {
      return SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(vertical: 12.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: AppColors.borderWarm,
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
              SizedBox(height: 14.h),
              Text(
                'Select collection',
                style: AppTypography.titleMedium.copyWith(
                  color: AppColors.inkText,
                ),
              ),
              SizedBox(height: 8.h),
              ...collections.map((c) {
                final isSelected = c.key == selectedKey;
                return ListTile(
                  onTap: () => Navigator.of(context).pop(c.key),
                  // A check mark rather than a radio: this is a navigation
                  // choice that closes the sheet, not a form field.
                  leading: Icon(
                    isSelected
                        ? Icons.check_circle_rounded
                        : Icons.circle_outlined,
                    color: isSelected
                        ? AppColors.emeraldInk
                        : AppColors.borderWarm,
                    size: 22.sp,
                  ),
                  title: Text(
                    c.name,
                    style: AppTypography.titleMedium.copyWith(
                      color: AppColors.inkText,
                    ),
                  ),
                  subtitle: Text(
                    '${c.author} · ${c.reliability} · ${c.totalHadiths} hadiths',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  trailing: Text(
                    c.arabicName,
                    textDirection: TextDirection.rtl,
                    style: AppTypography.arabicBody.copyWith(
                      fontSize: 16.sp,
                      color: AppColors.hadithAccent,
                    ),
                  ),
                  selected: isSelected,
                );
              }),
            ],
          ),
        ),
      );
    },
  );
}
