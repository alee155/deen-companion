import 'package:flutter/material.dart';
import 'package:deen_companion/core/motion/motion.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';

/// One half of the Islamic Names gender picker — a compact illustrated card
/// that doubles as the filter. Tapping the selected card clears the filter
/// (handled by the caller).
class GenderHeroCard extends StatelessWidget {
  final String imagePath;
  final String label;
  final int count;
  final Color accent;
  final Color accentBg;
  final bool selected;
  final bool dimmed;
  final VoidCallback onTap;

  const GenderHeroCard({
    super.key,
    required this.imagePath,
    required this.label,
    required this.count,
    required this.accent,
    required this.accentBg,
    required this.selected,
    required this.dimmed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Pressable(
      haptic: true,
      onTap: onTap,
      child: AnimatedOpacity(
        duration: context.motion.duration(AppMotion.fast),
        opacity: dimmed ? 0.5 : 1.0,
        child: AnimatedContainer(
          duration: context.motion.duration(AppMotion.fast),
          curve: AppMotion.entrance,
          padding: EdgeInsets.all(10.w),
          decoration: BoxDecoration(
            color: selected ? accentBg : AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(22.r),
            border: Border.all(
              color: selected ? accent : AppColors.borderWarm,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 48.w,
                height: 48.w,
                padding: EdgeInsets.all(2.w),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accentBg,
                  border: Border.all(color: accent.withValues(alpha: 0.5)),
                ),
                child: ClipOval(
                  child: Image.asset(imagePath, fit: BoxFit.cover),
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5.sp,
                        fontWeight: FontWeight.w700,
                        color: AppColors.inkText,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      '$count names',
                      style: TextStyle(
                        fontSize: 11.5.sp,
                        fontWeight: FontWeight.w700,
                        color: accent,
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedSwitcher(
                duration: context.motion.duration(AppMotion.fast),
                child: selected
                    ? Icon(
                        Icons.check_circle_rounded,
                        key: const ValueKey('on'),
                        size: 20.sp,
                        color: accent,
                      )
                    : SizedBox(key: const ValueKey('off'), width: 20.sp),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
