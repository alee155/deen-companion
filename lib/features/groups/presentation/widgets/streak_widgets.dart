import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../shared/widgets/islamic_ornaments.dart';
import '../../domain/entities/group_streak.dart';

/// Glass week strip meant to sit on the dark hero.
class WeekStrip extends StatelessWidget {
  final List<StreakDay> week;
  const WeekStrip({super.key, required this.week});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(22.r),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Row(
        children: [
          for (final d in week)
            Expanded(
              child: Column(
                children: [
                  Text(
                    DateFormat('E').format(d.date).substring(0, 1),
                    style: TextStyle(
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w700,
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                  ),
                  SizedBox(height: 6.h),
                  AnimatedContainer(
                    duration: context.motion.duration(AppMotion.normal),
                    curve: AppMotion.entrance,
                    width: 34.w,
                    height: 34.w,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: d.completed
                          ? AppColors.gold
                          : Colors.white.withValues(alpha: 0.06),
                      border: d.isToday && !d.completed
                          ? Border.all(color: AppColors.goldLight, width: 1.6)
                          : null,
                    ),
                    child: IconSwap(
                      child: d.completed
                          ? Icon(
                              Icons.check_rounded,
                              key: const ValueKey('done'),
                              size: 18.sp,
                              color: AppColors.heroSurface,
                            )
                          : d.isToday
                          ? Icon(
                              Icons.circle_outlined,
                              key: const ValueKey('today'),
                              size: 14.sp,
                              color: AppColors.goldLight,
                            )
                          : const SizedBox.shrink(key: ValueKey('none')),
                    ),
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    '${d.date.day}',
                    style: TextStyle(
                      fontSize: 10.sp,
                      fontWeight: d.isToday ? FontWeight.w800 : FontWeight.w500,
                      color: d.isToday
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class TodayProgressCard extends StatelessWidget {
  final GroupStreakSummary summary;
  const TodayProgressCard({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    final pct = (summary.todayProgress * 100).round();
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: AppColors.borderWarm),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 76.w,
            height: 76.w,
            child: Stack(
              alignment: Alignment.center,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: summary.todayProgress),
                  duration: context.motion.duration(AppMotion.value),
                  curve: AppMotion.entrance,
                  builder: (_, v, _) => CustomPaint(
                    size: Size.square(76.w),
                    painter: RingPainter(
                      progress: v,
                      track: AppColors.worshipAccent.withValues(alpha: 0.15),
                      color: AppColors.gold,
                      width: 7,
                    ),
                  ),
                ),
                Text(
                  '$pct%',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w800,
                    color: AppColors.inkText,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Today’s progress',
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.inkText,
                  ),
                ),
                SizedBox(height: 3.h),
                Text(
                  '${summary.completedTodayCount} of ${summary.memberCount} members have read today',
                  style: TextStyle(
                    fontSize: 12.sp,
                    height: 1.35,
                    color: AppColors.textSecondary,
                  ),
                ),
                if (summary.remainingToday > 0) ...[
                  SizedBox(height: 6.h),
                  Text(
                    '${summary.remainingToday} more to keep the streak alive',
                    style: TextStyle(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.amberDeep,
                    ),
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

class MemberTile extends StatelessWidget {
  final MemberActivity member;
  final int rank;
  const MemberTile({super.key, required this.member, required this.rank});

  @override
  Widget build(BuildContext context) {
    final done = member.completedToday;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 11.h),
      child: Row(
        children: [
          SizedBox(
            width: 20.w,
            child: Text(
              '$rank',
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.w800,
                color: AppColors.textMuted,
              ),
            ),
          ),
          Container(
            width: 42.w,
            height: 42.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: done ? AppColors.gold : AppColors.borderWarm,
                width: 1.6,
              ),
            ),
            child: ClipOval(
              child: member.imagePath == null
                  ? _initials()
                  : Image.asset(
                      member.imagePath!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _initials(),
                    ),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.name,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.inkText,
                  ),
                ),
                SizedBox(height: 2.h),
                Row(
                  children: [
                    Icon(
                      Icons.local_fire_department_rounded,
                      size: 13.sp,
                      color: AppColors.amber,
                    ),
                    SizedBox(width: 3.w),
                    Text(
                      '${member.streakDays} day streak',
                      style: TextStyle(
                        fontSize: 11.sp,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
            decoration: BoxDecoration(
              color: done
                  ? AppColors.gold.withValues(alpha: 0.16)
                  : AppColors.parchment,
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Text(
              done ? 'Done' : 'Pending',
              style: TextStyle(
                fontSize: 11.sp,
                fontWeight: FontWeight.w700,
                color: done ? AppColors.gold : AppColors.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _initials() => Container(
    color: AppColors.worshipAccentBg,
    alignment: Alignment.center,
    child: Text(
      member.initials,
      style: TextStyle(
        fontSize: 12.sp,
        fontWeight: FontWeight.w800,
        color: AppColors.worshipAccent,
      ),
    ),
  );
}
