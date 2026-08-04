import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/domain/explore_category.dart';

/// A single row in the Explore catalog — icon badge, title, one-line
/// description, and a chevron. Replaces the dense icon-only grid so each
/// feature reads as something with a purpose, not just a label.
class ExploreCategoryTile extends StatelessWidget {
  final ExploreCategory category;
  final VoidCallback onTap;

  const ExploreCategoryTile({
    super.key,
    required this.category,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceLight,
      borderRadius: BorderRadius.circular(16.r),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16.r),
        child: Container(
          padding: EdgeInsets.all(12.w),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(color: AppColors.borderWarm),
          ),
          child: Row(
            children: [
              Container(
                width: 46.w,
                height: 46.w,
                decoration: BoxDecoration(
                  color: category.accentBg,
                  borderRadius: BorderRadius.circular(13.r),
                ),
                child: Icon(
                  category.icon,
                  color: category.accentColor,
                  size: 20.sp,
                ),
              ),
              SizedBox(width: 14.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      category.label,
                      style: AppTypography.headline.copyWith(
                        fontSize: 14.5.sp,
                        color: AppColors.inkText,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      category.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8.w),
              Icon(
                Icons.chevron_right,
                color: AppColors.textMuted,
                size: 20.sp,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
