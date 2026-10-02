import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/motion/motion.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/prayer_times.dart';
import 'prayer_hero.dart';

/// Today's five prayers as a timeline: what's done, what's happening now,
/// what's next and how long until it.
class PrayerTimeline extends StatelessWidget {
  final PrayerTimes times;
  final ValueListenable<DateTime> now;
  const PrayerTimeline({super.key, required this.times, required this.now});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<DateTime>(
      valueListenable: now,
      builder: (context, t, _) {
        final current = times.current(t);
        final next = times.nextPrayer(t);
        final rows = times.ordered;
        return Column(
          children: [
            for (var i = 0; i < rows.length; i++)
              _Row(
                name: rows[i].key,
                time: rows[i].value,
                passed: !rows[i].value.isAfter(t),
                isCurrent: rows[i].key == current,
                isNext: next.value == rows[i].value,
                remaining: rows[i].value.difference(t),
                isLast: i == rows.length - 1,
              ).slideInAt(i),
          ],
        );
      },
    );
  }
}

class _Row extends StatelessWidget {
  final PrayerName name;
  final DateTime time;
  final bool passed, isCurrent, isNext, isLast;
  final Duration remaining;

  const _Row({
    required this.name,
    required this.time,
    required this.passed,
    required this.isCurrent,
    required this.isNext,
    required this.isLast,
    required this.remaining,
  });

  String _in(Duration d) {
    final h = d.inHours, m = d.inMinutes.remainder(60);
    return h > 0 ? 'in ${h}h ${m}m' : 'in ${m}m';
  }

  @override
  Widget build(BuildContext context) {
    final highlight = isNext || isCurrent;
    final Color dot = isNext
        ? AppColors.gold
        : isCurrent
        ? AppColors.success
        : passed
        ? AppColors.textMuted
        : AppColors.borderWarm;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Timeline rail.
          SizedBox(
            width: 26.w,
            child: Column(
              children: [
                SizedBox(height: 22.h),
                AnimatedContainer(
                  duration: context.motion.duration(AppMotion.normal),
                  curve: AppMotion.entrance,
                  width: highlight ? 16.w : 12.w,
                  height: highlight ? 16.w : 12.w,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: passed && !isCurrent
                        ? dot
                        : (highlight ? dot : AppColors.parchment),
                    border: Border.all(color: dot, width: 2),
                    boxShadow: isNext
                        ? [
                            BoxShadow(
                              color: AppColors.gold.withValues(alpha: 0.5),
                              blurRadius: 10,
                            ),
                          ]
                        : null,
                  ),
                  child: passed && !isCurrent
                      ? Icon(
                          Icons.check_rounded,
                          size: 8.sp,
                          color: AppColors.parchment,
                        )
                      : null,
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: passed
                          ? AppColors.textMuted.withValues(alpha: 0.4)
                          : AppColors.borderWarm,
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: 10.h),
              child: AnimatedContainer(
                duration: context.motion.duration(AppMotion.normal),
                curve: AppMotion.entrance,
                padding: EdgeInsets.symmetric(
                  horizontal: 14.w,
                  vertical: highlight ? 16.h : 13.h,
                ),
                decoration: BoxDecoration(
                  color: isNext
                      ? AppColors.heroSurface
                      : AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(20.r),
                  border: Border.all(
                    color: isNext
                        ? AppColors.gold
                        : isCurrent
                        ? AppColors.success.withValues(alpha: 0.5)
                        : AppColors.borderWarm,
                    width: isNext ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      prayerIcons[name],
                      size: 22.sp,
                      color: isNext
                          ? AppColors.goldLight
                          : passed && !isCurrent
                          ? AppColors.textMuted
                          : AppColors.emeraldInk,
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                prayerLabels[name]!,
                                style: TextStyle(
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.w700,
                                  color: isNext
                                      ? AppColors.onHeroSurface
                                      : passed && !isCurrent
                                      ? AppColors.textSecondary
                                      : AppColors.inkText,
                                ),
                              ),
                              SizedBox(width: 8.w),
                              Text(
                                prayerArabic[name]!,
                                textDirection: TextDirection.rtl,
                                style: TextStyle(
                                  fontFamily: 'AmiriQuran',
                                  fontSize: 15.sp,
                                  color: isNext
                                      ? AppColors.goldLight
                                      : AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                          if (isNext || isCurrent) ...[
                            SizedBox(height: 3.h),
                            Text(
                              isNext ? _in(remaining) : 'Current prayer time',
                              style: TextStyle(
                                fontSize: 11.sp,
                                fontWeight: FontWeight.w600,
                                color: isNext
                                    ? AppColors.gold
                                    : AppColors.success,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Text(
                      fmtClock(time),
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w700,
                        color: isNext
                            ? AppColors.onHeroSurface
                            : passed && !isCurrent
                            ? AppColors.textMuted
                            : AppColors.inkText,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
