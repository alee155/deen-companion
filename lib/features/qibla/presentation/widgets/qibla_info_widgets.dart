import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/motion/motion.dart';
import '../../../../core/theme/app_colors.dart';
import 'qibla_dial.dart' show qiblaAlignedColor;

BoxDecoration _card({Color? color, Color? border}) => BoxDecoration(
  color: color ?? AppColors.surfaceLight,
  borderRadius: BorderRadius.circular(20.r),
  border: Border.all(color: border ?? AppColors.borderWarm),
  boxShadow: [
    BoxShadow(
      color: AppColors.shadow,
      blurRadius: 14,
      offset: const Offset(0, 6),
    ),
  ],
);

/// Live guidance card: tells the user which way to turn, flips to a success
/// state when aligned and offers "Recheck" once the reading is locked.
class QiblaStatusCard extends StatelessWidget {
  final double? diff;
  final bool aligned;
  final bool locked;
  final VoidCallback onRecheck;

  const QiblaStatusCard({
    super.key,
    required this.diff,
    required this.aligned,
    required this.locked,
    required this.onRecheck,
  });

  @override
  Widget build(BuildContext context) {
    final good = aligned || locked;
    final color = good ? AppColors.success : AppColors.emeraldInkDark;
    final turnRight = (diff ?? 0) > 0;

    final IconData icon;
    final String title;
    final String subtitle;
    if (locked) {
      icon = Icons.verified_rounded;
      title = 'Locked onto the Qibla';
      subtitle = 'Your phone is facing the Kaaba. Tap Recheck to resume.';
    } else if (aligned) {
      icon = Icons.check_circle_rounded;
      title = "You're facing the Qibla";
      subtitle = 'Hold steady — the reading will lock in.';
    } else if (diff == null) {
      icon = Icons.navigation_rounded;
      title = 'Face the bearing below';
      subtitle = 'Use any compass or the sun to line up with it.';
    } else {
      icon = turnRight ? Icons.rotate_right_rounded : Icons.rotate_left_rounded;
      title =
          'Turn ${diff!.abs().round()}° to the ${turnRight ? 'right' : 'left'}';
      subtitle = 'Rotate until the Kaaba lines up with the top marker.';
    }

    return AnimatedContainer(
      duration: context.motion.duration(AppMotion.normal),
      curve: AppMotion.entrance,
      padding: EdgeInsets.all(16.w),
      decoration: _card(
        color: good
            ? Color.lerp(AppColors.surfaceLight, AppColors.success, 0.1)
            : null,
        border: good ? AppColors.success.withValues(alpha: 0.45) : null,
      ),
      child: Row(
        children: [
          AnimatedContainer(
            duration: context.motion.duration(AppMotion.normal),
            width: 48.w,
            height: 48.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.14),
            ),
            child: IconSwap(
              child: Icon(icon, key: ValueKey(icon), color: color, size: 26.sp),
            ),
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedText(
                  title,
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.inkText,
                  ),
                ),
                SizedBox(height: 3.h),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12.sp,
                    height: 1.35,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (locked)
            Pressable(
              onTap: onRecheck,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 9.h),
                decoration: BoxDecoration(
                  color: AppColors.emeraldInk,
                  borderRadius: BorderRadius.circular(20.r),
                ),
                child: Text(
                  'Recheck',
                  style: TextStyle(
                    fontSize: 12.5.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onEmeraldInk,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// One of the three stat tiles (bearing / heading / distance).
class QiblaStatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? caption;
  final bool highlight;

  const QiblaStatTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.caption,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final accent = highlight ? qiblaAlignedColor : AppColors.emeraldInk;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 14.h),
      decoration: _card(),
      child: Column(
        children: [
          Icon(icon, size: 20.sp, color: accent),
          SizedBox(height: 8.h),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 19.sp,
                fontWeight: FontWeight.w800,
                color: AppColors.inkText,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            label,
            style: TextStyle(fontSize: 11.sp, color: AppColors.textMuted),
          ),
          if (caption != null)
            Text(
              caption!,
              style: TextStyle(
                fontSize: 10.5.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
        ],
      ),
    );
  }
}

/// Orange-tinted notice with an icon, used for calibration and general tips.
class QiblaNoticeCard extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback? onTap;
  final bool warning;

  const QiblaNoticeCard({
    super.key,
    required this.icon,
    required this.text,
    this.onTap,
    this.warning = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = warning ? AppColors.amberDeep : AppColors.emeraldInk;
    return Pressable(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18.sp, color: color),
            SizedBox(width: 10.w),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 12.sp,
                  height: 1.4,
                  color: AppColors.inkText,
                ),
              ),
            ),
            if (onTap != null)
              Icon(Icons.chevron_right_rounded, size: 18.sp, color: color),
          ],
        ),
      ),
    );
  }
}
