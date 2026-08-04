import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/entities/prayer_times.dart';
import '../providers/prayer_times_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The monthly calendar, embedded directly on the Prayer Times screen.
///
/// This used to be its own screen, reached only via a small calendar icon
/// in the app bar — easy to miss for a feature that's actually one of the
/// app's main draws. It's self-contained (owns its own month-navigation
/// state) so it drops into any scrollable parent as a single widget.
class MonthlyPrayerCalendar extends StatefulWidget {
  const MonthlyPrayerCalendar({super.key});

  @override
  State<MonthlyPrayerCalendar> createState() => _MonthlyPrayerCalendarState();
}

class _MonthlyPrayerCalendarState extends State<MonthlyPrayerCalendar> {
  late DateTime _visibleMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _visibleMonth = DateTime(now.year, now.month);
  }

  void _shiftMonth(int delta) {
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + delta);
    });
  }

  @override
  Widget build(BuildContext context) {
    final arg = (year: _visibleMonth.year, month: _visibleMonth.month);

    return Consumer(
      builder: (context, ref, _) {
        final calendarAsync = ref.watch(prayerCalendarNotifierProvider(arg));
        final today = DateTime.now();
        final isCurrentMonth =
            _visibleMonth.year == today.year &&
            _visibleMonth.month == today.month;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Header(
              visibleMonth: _visibleMonth,
              onPrevious: () => _shiftMonth(-1),
              onNext: () => _shiftMonth(1),
            ),
            SizedBox(height: 14.h),
            calendarAsync.when(
              loading: () => const _CalendarSkeleton(),
              error: (error, _) => _ErrorCard(
                onRetry: () =>
                    ref.invalidate(prayerCalendarNotifierProvider(arg)),
              ),
              data: (days) => Column(
                children: [
                  for (var i = 0; i < days.length; i++)
                    Padding(
                      padding: EdgeInsets.only(bottom: 10.h),
                      child: _DayCard(
                        day: days[i],
                        isToday:
                            isCurrentMonth && days[i].fajr.day == today.day,
                      ).appearStaggered(i, maxIndex: 10),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  final DateTime visibleMonth;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  const _Header({
    required this.visibleMonth,
    required this.onPrevious,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(
              Icons.calendar_month_rounded,
              size: 18.sp,
              color: AppColors.emeraldInk,
            ),
            SizedBox(width: 8.w),
            Text(
              'Monthly Calendar',
              style: AppTypography.titleMedium.copyWith(
                color: AppColors.inkText,
              ),
            ),
          ],
        ),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 4.h),
          decoration: BoxDecoration(
            color: AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(24.r),
            border: Border.all(color: AppColors.borderWarm),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _NavButton(icon: Icons.chevron_left_rounded, onTap: onPrevious),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 6.w),
                child: Text(
                  DateFormat('MMM yyyy').format(visibleMonth),
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.inkText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _NavButton(icon: Icons.chevron_right_rounded, onTap: onNext),
            ],
          ),
        ),
      ],
    );
  }
}

class _NavButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _NavButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(4.w),
          child: Icon(icon, size: 20.sp, color: AppColors.inkText),
        ),
      ),
    );
  }
}

/// One day's row of prayer times, restyled as a proper card: a day badge
/// that reads clearly at a glance, soft elevation instead of a flat
/// border, and a gold accent treatment specifically for today rather than
/// a merely-thicker border.
class _DayCard extends StatelessWidget {
  final PrayerTimes day;
  final bool isToday;

  const _DayCard({required this.day, required this.isToday});

  static const _icons = {
    PrayerName.fajr: Icons.wb_twilight,
    PrayerName.dhuhr: Icons.wb_sunny_outlined,
    PrayerName.asr: Icons.wb_sunny,
    PrayerName.maghrib: Icons.wb_twilight_outlined,
    PrayerName.isha: Icons.nightlight_round,
  };

  static const _labels = {
    PrayerName.fajr: 'Fajr',
    PrayerName.dhuhr: 'Dhuhr',
    PrayerName.asr: 'Asr',
    PrayerName.maghrib: 'Maghrib',
    PrayerName.isha: 'Isha',
  };

  String _fmt(DateTime t) => DateFormat('h:mm a').format(t);
  String _weekday(DateTime t) => DateFormat('EEE').format(t);

  @override
  Widget build(BuildContext context) {
    final times = {
      PrayerName.fajr: day.fajr,
      PrayerName.dhuhr: day.dhuhr,
      PrayerName.asr: day.asr,
      PrayerName.maghrib: day.maghrib,
      PrayerName.isha: day.isha,
    };

    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
          color: isToday
              ? AppColors.gold.withValues(alpha: 0.55)
              : AppColors.borderWarm,
          width: isToday ? 1.4 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: (isToday ? AppColors.gold : Colors.black).withValues(
              alpha: isToday ? 0.16 : 0.04,
            ),
            blurRadius: isToday ? 16 : 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          _DayBadge(
            day: day.fajr,
            isToday: isToday,
            weekday: _weekday(day.fajr),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: times.entries.map((entry) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _icons[entry.key],
                      size: 15.sp,
                      color: isToday ? AppColors.gold : AppColors.textMuted,
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      _labels[entry.key]!,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textMuted,
                        fontSize: 9.sp,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      _fmt(entry.value),
                      style: AppTypography.caption.copyWith(
                        color: AppColors.inkText,
                        fontWeight: FontWeight.w700,
                        fontSize: 10.5.sp,
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _DayBadge extends StatelessWidget {
  final DateTime day;
  final bool isToday;
  final String weekday;

  const _DayBadge({
    required this.day,
    required this.isToday,
    required this.weekday,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46.w,
      padding: EdgeInsets.symmetric(vertical: 8.h),
      decoration: BoxDecoration(
        gradient: isToday
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.gold, AppColors.amberDeep],
              )
            : null,
        color: isToday ? null : AppColors.parchment,
        borderRadius: BorderRadius.circular(14.r),
      ),
      child: Column(
        children: [
          Text(
            weekday.toUpperCase(),
            style: AppTypography.caption.copyWith(
              color: isToday ? AppColors.emeraldInkDark : AppColors.textMuted,
              fontSize: 8.sp,
              letterSpacing: 0.4,
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            '${day.day}',
            style: AppTypography.headline.copyWith(
              color: isToday ? AppColors.emeraldInkDark : AppColors.inkText,
              fontSize: 17.sp,
            ),
          ),
        ],
      ),
    );
  }
}

class _CalendarSkeleton extends StatelessWidget {
  const _CalendarSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        4,
        (i) => Container(
          margin: EdgeInsets.only(bottom: 10.h),
          height: 78.h,
          decoration: BoxDecoration(
            color: AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(20.r),
            border: Border.all(color: AppColors.borderWarm),
          ),
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorCard({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: AppColors.borderWarm),
      ),
      child: Column(
        children: [
          Icon(
            Icons.cloud_off_outlined,
            size: 28.sp,
            color: AppColors.textMuted,
          ),
          SizedBox(height: 10.h),
          Text(
            "Couldn't load this month's calendar.",
            textAlign: TextAlign.center,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          SizedBox(height: 10.h),
          OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    );
  }
}
