import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../prayer_logs/presentation/providers/prayer_logs_providers.dart';
import '../../domain/special_days_calendar.dart';

/// "Your days": the running period as a grid of its days. Past days are ticked
/// with how many prayers were logged on them, today is highlighted, and the
/// rest are still to come. The counts come from the prayer logs the server
/// made on her behalf, so they are what actually happened.
class SpecialDaysCalendarCard extends ConsumerWidget {
  final SpecialDaysCalendar calendar;
  const SpecialDaysCalendarCard({super.key, required this.calendar});

  static const _columns = 5;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logs = ref.watch(
      prayerLogsRangeProvider((from: calendar.firstKey, to: calendar.todayKey)),
    );
    // Distinct prayers per day; unknown (loading, or the call failed) is left
    // blank rather than shown as zero.
    int? loggedOn(String key) {
      final byDate = logs.valueOrNull;
      if (byDate == null) return null;
      return (byDate[key] ?? const []).map((l) => l.prayer).toSet().length;
    }

    final left = calendar.daysLeftIncludingToday;
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(22.r),
        border: Border.all(color: AppColors.borderWarm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.calendar_month_rounded,
                size: 19.sp,
                color: AppColors.worshipAccent,
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  'Day ${calendar.todayNumber} of ${calendar.total}',
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w800,
                    color: AppColors.inkText,
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 3.h),
                decoration: BoxDecoration(
                  color: AppColors.worshipAccentBg,
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Text(
                  left == 1 ? 'Last day' : '$left days left',
                  style: TextStyle(
                    fontSize: 11.5.sp,
                    fontWeight: FontWeight.w800,
                    color: AppColors.worshipAccent,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          ClipRRect(
            borderRadius: BorderRadius.circular(4.r),
            child: LinearProgressIndicator(
              value: calendar.todayNumber / calendar.total,
              minHeight: 5.h,
              backgroundColor: AppColors.borderWarm,
              valueColor: AlwaysStoppedAnimation(AppColors.emeraldInk),
            ),
          ),
          SizedBox(height: 14.h),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            crossAxisCount: _columns,
            mainAxisSpacing: 8.w,
            crossAxisSpacing: 8.w,
            childAspectRatio: 0.78,
            children: [
              for (final day in calendar.days)
                _DayCell(
                  day: day,
                  logged: day.phase == SpecialDayPhase.upcoming
                      ? null
                      : loggedOn(day.key),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  final SpecialDayCell day;

  /// Prayers logged that day, or null when not known / not yet.
  final int? logged;
  const _DayCell({required this.day, required this.logged});

  @override
  Widget build(BuildContext context) {
    final today = day.phase == SpecialDayPhase.today;
    final past = day.phase == SpecialDayPhase.past;
    final fg = today ? AppColors.onEmeraldInk : AppColors.inkText;
    final sub = today
        ? AppColors.onEmeraldInk.withValues(alpha: 0.85)
        : AppColors.textMuted;

    final weekday = DateFormat('E').format(day.date);
    final String status = today
        ? 'Today'
        : past
        ? (logged == null ? '' : '$logged/5')
        : '';

    return Semantics(
      label:
          'Day ${day.number}, ${DateFormat('EEEE d MMMM').format(day.date)}'
          '${today
              ? ', today'
              : past
              ? (logged == null ? '' : ', $logged of 5 prayers logged')
              : ''}',
      excludeSemantics: true,
      child: Container(
        decoration: BoxDecoration(
          color: today
              ? AppColors.emeraldInk
              : past
              ? AppColors.emeraldInk.withValues(alpha: 0.12)
              : AppColors.parchment,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
            color: today
                ? AppColors.emeraldInk
                : past
                ? AppColors.emeraldInk.withValues(alpha: 0.35)
                : AppColors.borderWarm,
          ),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 4.h),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  weekday,
                  style: TextStyle(
                    fontSize: 10.5.sp,
                    fontWeight: FontWeight.w700,
                    color: sub,
                  ),
                ),
                Text(
                  '${day.date.day}',
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w800,
                    color: fg,
                    height: 1.15,
                  ),
                ),
                SizedBox(height: 2.h),
                if (past)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_rounded,
                        size: 12.sp,
                        color: AppColors.success,
                      ),
                      if (status.isNotEmpty) ...[
                        SizedBox(width: 2.w),
                        Text(
                          status,
                          style: TextStyle(
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w700,
                            color: AppColors.success,
                          ),
                        ),
                      ],
                    ],
                  )
                else
                  Text(
                    status.isEmpty ? ' ' : status,
                    style: TextStyle(
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w800,
                      color: sub,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
