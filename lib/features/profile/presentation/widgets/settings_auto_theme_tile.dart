import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/motion/motion.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../theme/domain/theme_schedule.dart';

/// The "Automatic" appearance: the look follows the prayer periods of the day.
/// Shows which period is active while it is on.
class SettingsAutoThemeTile extends StatelessWidget {
  final bool selected;

  /// The active period, shown while [selected].
  final ThemePeriod? period;
  final VoidCallback onTap;

  const SettingsAutoThemeTile({
    super.key,
    required this.selected,
    required this.period,
    required this.onTap,
  });

  static String periodLabel(ThemePeriod p) => switch (p) {
    ThemePeriod.fajr => 'Fajr',
    ThemePeriod.sunrise => 'Sunrise',
    ThemePeriod.dhuhr => 'Dhuhr',
    ThemePeriod.asr => 'Asr',
    ThemePeriod.maghrib => 'Maghrib',
    ThemePeriod.isha => 'Isha',
  };

  @override
  Widget build(BuildContext context) {
    final p = period;
    final subtitle = selected && p != null
        ? 'Now: ${periodLabel(p)} · changes with the day'
        : 'Follows Fajr, Sunrise, Dhuhr, Asr, Maghrib and Isha';
    return Pressable(
      onTap: onTap,
      haptic: !selected,
      scale: 0.98,
      child: AnimatedContainer(
        duration: context.motion.duration(AppMotion.fast),
        curve: AppMotion.entrance,
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(22.r),
          // Constant width: only the colour changes, so selecting never
          // nudges the layout.
          border: Border.all(
            color: selected ? AppColors.emeraldInk : AppColors.borderWarm,
            width: 1.6,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.brightness_auto_rounded,
              color: selected ? AppColors.emeraldInk : AppColors.textMuted,
              size: 26.sp,
            ),
            SizedBox(width: 14.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Automatic',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w800,
                      color: AppColors.inkText,
                    ),
                  ),
                  SizedBox(height: 3.h),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            // Always laid out, only faded, so the row never changes width.
            Opacity(
              opacity: selected ? 1 : 0,
              child: Icon(
                Icons.check_circle_rounded,
                color: AppColors.emeraldInk,
                size: 22.sp,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
