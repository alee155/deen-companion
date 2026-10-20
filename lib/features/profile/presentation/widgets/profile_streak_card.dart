import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../prayer_logs/presentation/prayer_labels.dart';
import '../../../prayer_times/domain/entities/prayer_times.dart';
import '../../../streaks/domain/entities/my_streaks.dart';

/// The signed-in user's streaks: the longest one running now (and where), the
/// best ever, and a streak for each of the five prayers.
class ProfileStreakCard extends StatelessWidget {
  final MyStreaks streaks;
  const ProfileStreakCard({super.key, required this.streaks});

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
                          value: streaks.currentBest,
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
                          streaks.currentBest == 1 ? 'day' : 'days',
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
                    value: streaks.longest,
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
          SizedBox(height: 14.h),
          Row(
            children: [
              for (final p in PrayerName.values)
                Expanded(
                  child: _PrayerStreak(prayer: p, streak: streaks.prayer(p)),
                ),
            ],
          ),
          SizedBox(height: 10.h),
          Text(
            _caption(),
            style: TextStyle(fontSize: 12.sp, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  String _caption() {
    final lead = streaks.leading;
    if (lead == null) return 'Join a group to start a streak with others.';
    if (streaks.currentBest == 0) {
      return 'Log ${lead.minPrayers == 1 ? 'a prayer' : '${lead.minPrayers} prayers'} today to start a streak in ${lead.name}.';
    }
    return 'Longest run right now: ${lead.name}.';
  }
}

/// One prayer's own streak: its icon over the number of days in a row.
class _PrayerStreak extends StatelessWidget {
  final PrayerName prayer;
  final PrayerStreak streak;
  const _PrayerStreak({required this.prayer, required this.streak});

  @override
  Widget build(BuildContext context) {
    final on = streak.currentStreak > 0;
    return Semantics(
      label: '${prayer.label} streak, ${streak.currentStreak} days',
      excludeSemantics: true,
      child: Column(
        children: [
          Container(
            width: 36.w,
            height: 36.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: on
                  ? AppColors.gold.withValues(alpha: 0.2)
                  : AppColors.parchment,
              border: Border.all(
                color: on ? AppColors.gold : AppColors.borderWarm,
              ),
            ),
            child: Icon(
              prayer.icon,
              size: 17.sp,
              color: on ? AppColors.amberDeep : AppColors.textMuted,
            ),
          ),
          SizedBox(height: 5.h),
          Text(
            '${streak.currentStreak}',
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w800,
              color: on ? AppColors.inkText : AppColors.textMuted,
            ),
          ),
          Text(
            prayer.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 10.sp, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}
