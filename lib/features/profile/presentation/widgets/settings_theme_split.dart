import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/motion/motion.dart';
import '../../../../core/theme/app_colors.dart';

/// Light/Dark split panel — replaces the old three-way segmented control
/// now that the app only ever offers these two appearances.
class SettingsThemeSplit extends StatelessWidget {
  final bool isDark;
  final ValueChanged<bool> onChanged;

  const SettingsThemeSplit({
    super.key,
    required this.isDark,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28.r),
      child: SizedBox(
        height: 128.h,
        child: Row(
          children: [
            Expanded(
              child: _half(
                context,
                false,
              ).slideIn(RevealDirection.start, fade: false, distance: 40),
            ),
            Expanded(
              child: _half(context, true).slideIn(
                RevealDirection.end,
                fade: false,
                distance: 40,
                delay: const Duration(milliseconds: 60),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _half(BuildContext context, bool dark) {
    final selected = isDark == dark;
    final fg = dark ? AppColors.onEmeraldInk : AppColors.inkText;

    return Pressable(
      onTap: () => onChanged(dark),
      haptic: !selected,
      scale: 0.98,
      child: Container(
        color: dark ? AppColors.inkText : AppColors.surfaceLight,
        padding: EdgeInsets.all(16.w),
        child: AnimatedOpacity(
          duration: context.motion.duration(AppMotion.fast),
          curve: AppMotion.entrance,
          opacity: selected ? 1 : 0.45,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                dark ? Icons.nightlight_round : Icons.wb_sunny_rounded,
                color: dark ? AppColors.onEmeraldInk : AppColors.emeraldInk,
                size: 26.sp,
              ),
              const Spacer(),
              Text(
                dark ? 'Dark' : 'Light',
                style: TextStyle(
                  fontSize: 20.sp,
                  fontWeight: FontWeight.w900,
                  color: fg,
                ),
              ),
              SizedBox(height: 6.h),
              Row(
                children: [
                  AnimatedContainer(
                    duration: context.motion.duration(AppMotion.fast),
                    curve: AppMotion.entrance,
                    height: 8.h,
                    width: selected ? 22.w : 8.h,
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.emeraldInk
                          : AppColors.textMuted,
                      borderRadius: BorderRadius.circular(6.r),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Text(
                    selected ? 'Active' : 'Tap to use',
                    style: TextStyle(
                      fontSize: 11.sp,
                      color: dark
                          ? AppColors.onEmeraldInk.withValues(alpha: 0.6)
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
