import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/motion/motion.dart';
import '../../../../core/theme/app_colors.dart';

/// One figure in the [ProfileStatsStrip].
class ProfileStat {
  final String label;
  final num value;
  final IconData icon;

  const ProfileStat({
    required this.label,
    required this.value,
    required this.icon,
  });
}

/// A single card of figures that straddles the bottom edge of the header.
/// Display only: the shortcuts below it do the navigating.
class ProfileStatsStrip extends StatelessWidget {
  static const height = 84.0;

  final List<ProfileStat> stats;
  const ProfileStatsStrip({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height.h,
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: AppColors.borderWarm),
        boxShadow: [
          BoxShadow(
            color: AppColors.inkText.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          for (var i = 0; i < stats.length; i++) ...[
            if (i > 0)
              VerticalDivider(
                width: 1,
                indent: 20.h,
                endIndent: 20.h,
                color: AppColors.borderWarm,
              ),
            Expanded(child: _cell(stats[i])),
          ],
        ],
      ),
    );
  }

  TextStyle get _valueStyle => TextStyle(
    fontSize: 22.sp,
    fontWeight: FontWeight.w800,
    color: AppColors.inkText,
    height: 1,
  );

  Widget _cell(ProfileStat s) => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      // Fractional values (points can be) are shown exactly, not animated.
      s.value == s.value.roundToDouble()
          ? AnimatedCount(value: s.value, fromZero: true, style: _valueStyle)
          : Text('${s.value}', style: _valueStyle),
      SizedBox(height: 6.h),
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(s.icon, size: 12.sp, color: AppColors.gold),
          SizedBox(width: 4.w),
          Text(
            s.label,
            style: TextStyle(fontSize: 11.5.sp, color: AppColors.textSecondary),
          ),
        ],
      ),
    ],
  );
}
