import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/entities/prayer_calculation_settings.dart';
import '../providers/prayer_calculation_settings_provider.dart';

Future<void> showCalculationMethodPicker(BuildContext context, WidgetRef ref) {
  final current = ref.read(prayerCalculationSettingsProvider).method;

  return showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.surfaceLight,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
    ),
    isScrollControlled: true,
    builder: (context) {
      return SafeArea(
        child: DraggableScrollableSheet(
          initialChildSize: 0.7,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 8.h),
                  child: Text(
                    'Calculation Method',
                    style: AppTypography.headline.copyWith(
                      color: AppColors.inkText,
                      fontSize: 16.sp,
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20.w),
                  child: Text(
                    'Choose the method your local mosque or authority uses. '
                    'Times can shift by several minutes between methods.',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                SizedBox(height: 8.h),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: PrayerCalculationMethod.values.length,
                    itemBuilder: (context, index) {
                      final method = PrayerCalculationMethod.values[index];
                      final isSelected = method == current;
                      return ListTile(
                        title: Text(
                          method.label,
                          style: AppTypography.bodyLarge.copyWith(
                            color: AppColors.inkText,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w400,
                          ),
                        ),
                        trailing: isSelected
                            ? Icon(
                                Icons.check_circle,
                                color: AppColors.emeraldInk,
                              )
                            : null,
                        onTap: () {
                          ref
                              .read(prayerCalculationSettingsProvider.notifier)
                              .setMethod(method);
                          Navigator.of(context).pop();
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      );
    },
  );
}

Future<void> showAsrSchoolPicker(BuildContext context, WidgetRef ref) {
  final current = ref.read(prayerCalculationSettingsProvider).school;

  return showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.surfaceLight,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
    ),
    builder: (context) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 8.h),
              child: Text(
                'Asr Juristic School',
                style: AppTypography.headline.copyWith(
                  color: AppColors.inkText,
                  fontSize: 16.sp,
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w),
              child: Text(
                'Hanafi Asr falls later than Shafi/Maliki/Hanbali Asr.',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            SizedBox(height: 8.h),
            for (final school in AsrSchool.values)
              ListTile(
                title: Text(
                  school.label,
                  style: AppTypography.bodyLarge.copyWith(
                    color: AppColors.inkText,
                    fontWeight: school == current
                        ? FontWeight.w700
                        : FontWeight.w400,
                  ),
                ),
                trailing: school == current
                    ? Icon(Icons.check_circle, color: AppColors.emeraldInk)
                    : null,
                onTap: () {
                  ref
                      .read(prayerCalculationSettingsProvider.notifier)
                      .setSchool(school);
                  Navigator.of(context).pop();
                },
              ),
            SizedBox(height: 12.h),
          ],
        ),
      );
    },
  );
}
