import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/motion/motion.dart';
import '../../../../core/theme/app_colors.dart';

class SettingsOptionChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const SettingsOptionChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      haptic: true,
      child: AnimatedContainer(
        duration: context.motion.duration(AppMotion.fast),
        curve: AppMotion.entrance,
        height: 46.h,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.emeraldInk : Colors.transparent,
          borderRadius: BorderRadius.circular(23.r),
          border: Border.all(
            color: selected ? AppColors.emeraldInk : AppColors.borderWarm,
            width: 1.2.w,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5.sp,
            fontWeight: FontWeight.w800,
            color: selected ? AppColors.onEmeraldInk : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
