import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../groups/domain/entities/group_streak.dart';

/// The signed-in user's streak: big number, this week's dots, best streak.
class ProfileStreakCard extends StatelessWidget {
  final UserStreakStats stats;
  const ProfileStreakCard({super.key, required this.stats});

  static const _days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(26.r),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 52.w,
                height: 52.w,
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.local_fire_department_rounded,
                  size: 28.sp,
                  color: AppColors.amber,
                ),
              ),
              SizedBox(width: 14.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CURRENT STREAK',
                      style: TextStyle(
                        fontSize: 10.sp,
                        letterSpacing: 1.4,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textMuted,
                      ),
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        AnimatedCount(
                          value: stats.currentStreak,
                          fromZero: true,
                          style: TextStyle(
                            fontSize: 34.sp,
                            fontWeight: FontWeight.w800,
                            color: AppColors.inkText,
                            height: 1.1,
                          ),
                        ),
                        SizedBox(width: 6.w),
                        AnimatedText(
                          stats.currentStreak == 1 ? 'day' : 'days',
                          style: TextStyle(
                            fontSize: 14.sp,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'BEST',
                    style: TextStyle(
                      fontSize: 10.sp,
                      letterSpacing: 1.4,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textMuted,
                    ),
                  ),
                  AnimatedCount(
                    value: stats.longestStreak,
                    style: TextStyle(
                      fontSize: 22.sp,
                      fontWeight: FontWeight.w800,
                      color: AppColors.gold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 16.h),
          Row(
            children: [
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: Column(
                    children: [
                      AnimatedContainer(
                        duration: context.motion.duration(AppMotion.normal),
                        curve: AppMotion.entrance,
                        width: 32.w,
                        height: 32.w,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: stats.week[i]
                              ? AppColors.gold
                              : AppColors.parchment,
                          border: i == stats.todayIndex && !stats.week[i]
                              ? Border.all(color: AppColors.gold, width: 1.6)
                              : null,
                        ),
                        child: IconSwap(
                          child: stats.week[i]
                              ? Icon(
                                  Icons.check_rounded,
                                  key: const ValueKey('done'),
                                  size: 17.sp,
                                  color: AppColors.heroSurface,
                                )
                              : const SizedBox.shrink(key: ValueKey('todo')),
                        ),
                      ),
                      SizedBox(height: 5.h),
                      Text(
                        _days[i],
                        style: TextStyle(
                          fontSize: 10.sp,
                          fontWeight: i == stats.todayIndex
                              ? FontWeight.w800
                              : FontWeight.w500,
                          color: i == stats.todayIndex
                              ? AppColors.inkText
                              : AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          SizedBox(height: 12.h),
          Text(
            '${stats.activeDaysThisWeek} of 7 days active this week',
            style: TextStyle(fontSize: 12.sp, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
