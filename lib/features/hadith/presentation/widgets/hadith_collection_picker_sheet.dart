import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/entities/hadith_collection.dart';

/// A modal bottom sheet acting as the collection "dropdown" — tapping
/// the pill in the hub screen opens this to switch collections.
Future<String?> showHadithCollectionPicker(
  BuildContext context, {
  required List<HadithCollection> collections,
  required String selectedKey,
}) {
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: AppColors.surfaceLight,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
    ),
    builder: (context) {
      return SafeArea(
        child: Padding(
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
                  leading: Radio<String>(
                    value: c.key,
                    groupValue: selectedKey,
                    activeColor: AppColors.emeraldInk,
                    onChanged: (_) => Navigator.of(context).pop(c.key),
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
