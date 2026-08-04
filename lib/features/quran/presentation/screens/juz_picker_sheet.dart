import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';

/// Switches the Juz being read, without a trip back to the hub. Returns the
/// chosen Juz number, or null if dismissed. A grid rather than a list — with
/// 30 fixed, numbered items, jumping straight to a number is faster than
/// scrolling a long list of rows.
Future<int?> showJuzPickerSheet(BuildContext context, {required int selected}) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surfaceLight,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
    ),
    builder: (context) {
      return SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 20.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
              Text(
                'Jump to Juz',
                style: AppTypography.titleMedium.copyWith(
                  color: AppColors.inkText,
                ),
              ),
              SizedBox(height: 14.h),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 6,
                  mainAxisSpacing: 10.h,
                  crossAxisSpacing: 10.w,
                  childAspectRatio: 1,
                ),
                itemCount: 30,
                itemBuilder: (context, index) {
                  final number = index + 1;
                  final isSelected = number == selected;
                  return InkWell(
                    borderRadius: BorderRadius.circular(10.r),
                    onTap: () => Navigator.of(context).pop(number),
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.emeraldInk
                            : AppColors.parchment,
                        borderRadius: BorderRadius.circular(10.r),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.emeraldInk
                              : AppColors.borderWarm,
                        ),
                      ),
                      child: Text(
                        '$number',
                        style: AppTypography.bodyMedium.copyWith(
                          color: isSelected
                              ? AppColors.surfaceLight
                              : AppColors.inkText,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      );
    },
  );
}
