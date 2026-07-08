import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';

class JuzListScreen extends StatelessWidget {
  const JuzListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.parchment,
      appBar: AppBar(
        title: const Text('Juz'),
        backgroundColor: AppColors.surfaceLight,
        foregroundColor: AppColors.inkText,
      ),
      body: GridView.builder(
        padding: EdgeInsets.all(20.w),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          mainAxisSpacing: 12.h,
          crossAxisSpacing: 12.w,
          childAspectRatio: 1,
        ),
        itemCount: 30,
        itemBuilder: (context, index) {
          final juzNumber = index + 1;
          return InkWell(
            borderRadius: BorderRadius.circular(14.r),
            onTap: () => context.push('/quran/juz/$juzNumber'),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(14.r),
                border: Border.all(color: AppColors.borderWarm),
              ),
              alignment: Alignment.center,
              child: Text(
                '$juzNumber',
                style: AppTypography.titleMedium.copyWith(
                  color: AppColors.emeraldInk,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
