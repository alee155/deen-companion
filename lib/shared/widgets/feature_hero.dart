import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../core/motion/motion.dart';
import '../../core/theme/app_colors.dart';
import 'islamic_ornaments.dart';

/// The dark hero the updated feature screens open with (Notifications, Prayer
/// Reminders, Ayat & Hadith) — same construction
/// as the Groups and Prayer Times heroes: ink gradient, faint geometric
/// lattice, a large ghost icon, title, subtitle and frosted chips.
class FeatureHero extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData ghostIcon;
  final List<FeatureHeroChip> chips;

  /// A shorter header for detail screens: smaller title, a one-line subtitle
  /// and tighter spacing, so the content starts higher. The default size is
  /// for feature landing screens.
  final bool compact;

  /// Whether the title, subtitle and chips slide in. Off for a hero that must
  /// stay still while the screen below it changes.
  final bool animate;

  const FeatureHero({
    super.key,
    required this.title,
    required this.subtitle,
    required this.ghostIcon,
    this.chips = const [],
    this.compact = false,
    this.animate = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: AppColors.heroGradient,
        ),
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular((compact ? 28 : 36).r),
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: GeometricPattern(
              color: AppColors.goldLight.withValues(alpha: 0.08),
              cell: 52,
            ),
          ),
          Positioned(
            right: (compact ? -10 : -24).w,
            top: (compact ? 30 : 40).h,
            child: Icon(
              ghostIcon,
              size: (compact ? 96 : 170).sp,
              color: AppColors.gold.withValues(alpha: 0.10),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              24.w,
              MediaQuery.of(context).padding.top + (compact ? 50 : 66).h,
              24.w,
              (compact ? 14 : 26).h,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: (compact ? 22 : 30).sp,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    height: 1.1,
                  ),
                ).slideInIf(animate, RevealDirection.topStart),
                SizedBox(height: (compact ? 3 : 6).h),
                Text(
                  subtitle,
                  maxLines: compact ? 1 : null,
                  overflow: compact ? TextOverflow.ellipsis : null,
                  style: TextStyle(
                    fontSize: (compact ? 12 : 13).sp,
                    height: 1.45,
                    color: AppColors.onHeroSurface.withValues(alpha: 0.78),
                  ),
                ).slideInIf(
                  animate,
                  RevealDirection.start,
                  delay: const Duration(milliseconds: 70),
                ),
                if (chips.isNotEmpty) ...[
                  SizedBox(height: (compact ? 10 : 16).h),
                  Wrap(
                    spacing: 8.w,
                    runSpacing: (compact ? 6 : 8).h,
                    children: [
                      for (var i = 0; i < chips.length; i++)
                        chips[i].build().slideInIf(
                          animate,
                          i.isEven
                              ? RevealDirection.bottomStart
                              : RevealDirection.bottomEnd,
                          delay: Duration(milliseconds: 130 + 50 * i),
                          duration: AppMotion.normal,
                          distance: 18,
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class FeatureHeroChip {
  final IconData icon;
  final String text;
  const FeatureHeroChip(this.icon, this.text);

  Widget build() => Container(
    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(16.r),
      border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14.sp, color: AppColors.goldLight),
        SizedBox(width: 6.w),
        // Flexible, so a long chip shortens instead of overflowing the hero on
        // a narrow phone or at large text.
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12.sp, color: Colors.white),
          ),
        ),
      ],
    ),
  );
}

extension _HeroReveal on Widget {
  /// [slideIn], or the widget as it is when [animate] is false.
  Widget slideInIf(
    bool animate,
    RevealDirection direction, {
    Duration delay = Duration.zero,
    Duration? duration,
    double? distance,
  }) {
    if (!animate) return this;
    return slideIn(
      direction,
      delay: delay,
      duration: duration ?? AppMotion.slow,
      distance: distance ?? 24,
    );
  }
}
