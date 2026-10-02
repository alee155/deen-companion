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

  const FeatureHero({
    super.key,
    required this.title,
    required this.subtitle,
    required this.ghostIcon,
    this.chips = const [],
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
          colors: [AppColors.heroSurface, AppColors.emeraldInkDark],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(36.r)),
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
            right: -24.w,
            top: 40.h,
            child: Icon(
              ghostIcon,
              size: 170.sp,
              color: AppColors.gold.withValues(alpha: 0.10),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              24.w,
              MediaQuery.of(context).padding.top + 66.h,
              24.w,
              26.h,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 30.sp,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    height: 1.1,
                  ),
                ).slideIn(RevealDirection.topStart),
                SizedBox(height: 6.h),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13.sp,
                    height: 1.45,
                    color: AppColors.onHeroSurface.withValues(alpha: 0.78),
                  ),
                ).slideIn(
                  RevealDirection.start,
                  delay: const Duration(milliseconds: 70),
                ),
                if (chips.isNotEmpty) ...[
                  SizedBox(height: 16.h),
                  Wrap(
                    spacing: 8.w,
                    runSpacing: 8.h,
                    children: [
                      for (var i = 0; i < chips.length; i++)
                        chips[i].build().slideIn(
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
        Text(
          text,
          style: TextStyle(fontSize: 12.sp, color: Colors.white),
        ),
      ],
    ),
  );
}
