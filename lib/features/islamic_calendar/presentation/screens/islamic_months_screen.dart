import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../providers/islamic_calendar_providers.dart';

class IslamicMonthsScreen extends ConsumerWidget {
  const IslamicMonthsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final monthsAsync = ref.watch(islamicMonthsNotifierProvider);

    return Scaffold(
      backgroundColor: AppColors.parchment,
      appBar: AppBar(
        title: const Text('Islamic Months'),
        backgroundColor: AppColors.surfaceLight,
        foregroundColor: AppColors.inkText,
      ),
      body: monthsAsync.when(
        data: (months) => ListView.separated(
          padding: EdgeInsets.all(20.w),
          itemCount: months.length,
          separatorBuilder: (_, __) => SizedBox(height: 10.h),
          itemBuilder: (context, index) {
            final m = months[index];
            return Container(
              padding: EdgeInsets.all(14.w),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(14.r),
                border: Border.all(color: AppColors.borderWarm),
              ),
              child: Row(
                children: [
                  Container(
                    width: 34.w,
                    height: 34.w,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.hijriAccentBg,
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    child: Text(
                      '${m.number}',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.hijriAccent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              m.nameEnglish,
                              style: AppTypography.titleMedium.copyWith(
                                color: AppColors.inkText,
                              ),
                            ),
                            SizedBox(width: 8.w),
                            Text(
                              m.nameArabic,
                              textDirection: TextDirection.rtl,
                              style: AppTypography.arabicBody.copyWith(
                                fontSize: 15.sp,
                                color: AppColors.hijriAccent,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          m.significance,
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(error.toString())),
      ),
    );
  }
}
