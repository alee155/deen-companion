import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/motion/motion.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/domain/explore_category.dart';
import '../../../../shared/domain/explore_icon_assets.dart';

/// One entry in Explore's grid — an icon tile with its label underneath,
/// the same visual language as Home's category row. Categories with a real
/// illustrated icon (see [exploreIconAssets]) show it plainly, like Home;
/// the rest fall back to a tinted Material icon as an explicit placeholder.
class ExploreGridTile extends StatelessWidget {
  final ExploreCategory category;
  final VoidCallback onTap;

  const ExploreGridTile({
    super.key,
    required this.category,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final iconAsset = exploreIconAssets[category.id];

    return Pressable(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 62.h,
            width: 62.h,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: iconAsset != null
                  ? AppColors.surfaceLight
                  : category.accentBg,
              borderRadius: BorderRadius.circular(18.r),
              border: Border.all(color: AppColors.borderWarm, width: 1.2.w),
            ),
            child: iconAsset != null
                ? Padding(
                    padding: EdgeInsets.all(13.w),
                    child: Image.asset(iconAsset, fit: BoxFit.contain),
                  )
                : Icon(category.icon, color: category.accentColor, size: 26.sp),
          ),
          SizedBox(height: 8.h),
          SizedBox(
            height: 34.h,
            child: Text(
              category.label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.bodyMedium.copyWith(
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.inkText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
