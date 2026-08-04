import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/entities/prayer_times.dart';
import '../providers/prayer_times_provider.dart';
import '../../../../shared/widgets/deen_app_bar.dart';

class PrayerCalendarScreen extends ConsumerStatefulWidget {
  const PrayerCalendarScreen({super.key});

  @override
  ConsumerState<PrayerCalendarScreen> createState() =>
      _PrayerCalendarScreenState();
}

class _PrayerCalendarScreenState extends ConsumerState<PrayerCalendarScreen> {
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
    final calendarAsync = ref.watch(prayerCalendarNotifierProvider(arg));
    final today = DateTime.now();
    final isCurrentMonth =
        _visibleMonth.year == today.year && _visibleMonth.month == today.month;

    return Scaffold(
      backgroundColor: AppColors.parchment,
      appBar: const DeenAppBar(title: 'Prayer Calendar'),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(16.w),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => _shiftMonth(-1),
                ),
                Text(
                  DateFormat('MMMM yyyy').format(_visibleMonth),
                  style: AppTypography.headline.copyWith(
                    color: AppColors.inkText,
                    fontSize: 16.sp,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => _shiftMonth(1),
                ),
              ],
            ),
          ),
          Expanded(
            child: calendarAsync.when(
              loading: () => Center(
                child: CircularProgressIndicator(color: AppColors.gold),
              ),
              error: (error, _) => Center(
                child: Padding(
                  padding: EdgeInsets.all(24.w),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.cloud_off_outlined,
                        size: 32.sp,
                        color: AppColors.textMuted,
                      ),
                      SizedBox(height: 10.h),
                      Text(
                        "Couldn't load this month's calendar. Check your "
                        'connection and try again.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ),
              data: (days) => ListView.separated(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                itemCount: days.length,
                separatorBuilder: (context, index) => SizedBox(height: 8.h),
                itemBuilder: (context, index) {
                  final day = days[index];
                  final isToday = isCurrentMonth && day.fajr.day == today.day;
                  return _DayRow(
                    day: day,
                    isToday: isToday,
                  ).appearStaggered(index, maxIndex: 8);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DayRow extends StatelessWidget {
  final PrayerTimes day;
  final bool isToday;

  const _DayRow({required this.day, required this.isToday});

  String _fmt(DateTime t) => DateFormat('h:mm a').format(t);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: isToday
            ? AppColors.emeraldInk.withValues(alpha: 0.06)
            : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: isToday ? AppColors.emeraldInk : AppColors.borderWarm,
          width: isToday ? 1.4 : 1,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 38.w,
            child: Text(
              '${day.fajr.day}',
              style: AppTypography.titleMedium.copyWith(
                color: isToday ? AppColors.emeraldInk : AppColors.inkText,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(child: _TimeChip('Fajr', _fmt(day.fajr))),
          Expanded(child: _TimeChip('Dhuhr', _fmt(day.dhuhr))),
          Expanded(child: _TimeChip('Asr', _fmt(day.asr))),
          Expanded(child: _TimeChip('Maghrib', _fmt(day.maghrib))),
          Expanded(child: _TimeChip('Isha', _fmt(day.isha))),
        ],
      ),
    );
  }
}

class _TimeChip extends StatelessWidget {
  final String label;
  final String time;
  const _TimeChip(this.label, this.time);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 9.sp, color: AppColors.textMuted),
        ),
        SizedBox(height: 2.h),
        Text(
          time,
          style: TextStyle(
            fontSize: 10.5.sp,
            fontWeight: FontWeight.w600,
            color: AppColors.inkText,
          ),
        ),
      ],
    );
  }
}
