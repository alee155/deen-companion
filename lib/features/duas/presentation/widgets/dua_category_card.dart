import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/entities/dua_category.dart';

class DuaCategoryCard extends StatelessWidget {
  final DuaCategory category;
  final VoidCallback onTap;

  const DuaCategoryCard({
    super.key,
    required this.category,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14.r),
      child: Container(
        padding: EdgeInsets.all(14.w),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(14.r),
          border: Border(left: BorderSide(color: AppColors.gold, width: 3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              category.name,
              style: AppTypography.titleMedium.copyWith(
                color: AppColors.inkText,
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              category.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            SizedBox(height: 10.h),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
              decoration: BoxDecoration(
                color: AppColors.duasAccentBg,
                borderRadius: BorderRadius.circular(6.r),
              ),
              child: Text(
                '${category.count} duas',
                style: AppTypography.caption.copyWith(
                  color: AppColors.duasAccent,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
