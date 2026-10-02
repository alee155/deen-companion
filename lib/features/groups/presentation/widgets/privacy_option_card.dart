import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';

class PrivacyOptionCard extends StatelessWidget {
  final bool selected;
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  const PrivacyOptionCard({
    super.key,
    required this.selected,
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: context.motion.duration(AppMotion.normal),
      curve: AppMotion.entrance,
      decoration: BoxDecoration(
        color: selected ? AppColors.toolsAccentBg : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(22.r),
        border: Border.all(
          color: selected ? AppColors.gold : AppColors.borderWarm,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: PressScale(
        child: InkWell(
          borderRadius: BorderRadius.circular(22.r),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.all(14.w),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: context.motion.duration(AppMotion.fast),
                  curve: AppMotion.entrance,
                  width: 44.w,
                  height: 44.w,
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.heroSurface
                        : AppColors.parchment,
                    borderRadius: BorderRadius.circular(14.r),
                  ),
                  child: Icon(
                    icon,
                    size: 22.sp,
                    color: selected ? AppColors.goldLight : AppColors.textMuted,
                  ),
                ),
                SizedBox(width: 14.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w700,
                          color: AppColors.inkText,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 12.sp,
                          height: 1.35,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconSwap(
                  child: Icon(
                    selected
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    key: ValueKey(selected),
                    color: selected ? AppColors.gold : AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
