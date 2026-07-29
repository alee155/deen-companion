import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/entities/prayer_times.dart';

class NextPrayerHeroCard extends StatefulWidget {
  final PrayerTimes prayerTimes;
  const NextPrayerHeroCard({super.key, required this.prayerTimes});

  @override
  State<NextPrayerHeroCard> createState() => _NextPrayerHeroCardState();
}

class _NextPrayerHeroCardState extends State<NextPrayerHeroCard> {
  late Timer _ticker;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(minutes: 1), (_) {
      setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _ticker.cancel();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    if (hours > 0) return '${hours}h ${minutes}m left';
    return '${minutes}m left';
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'pm' : 'am';
    return '$hour:$minute $period';
  }

  String _label(PrayerName name) => switch (name) {
    PrayerName.fajr => 'Fajr',
    PrayerName.dhuhr => 'Dhuhr',
    PrayerName.asr => 'Asr',
    PrayerName.maghrib => 'Maghrib',
    PrayerName.isha => 'Isha',
  };

  @override
  Widget build(BuildContext context) {
    final next = widget.prayerTimes.nextPrayer(_now);

    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: AppColors.emeraldInk,
        borderRadius: BorderRadius.circular(18.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            widget.prayerTimes.hijriDate,
            style: AppTypography.bodyMedium.copyWith(color: AppColors.gold),
          ),
          SizedBox(height: 14.h),
          Text(
            _formatTime(next.value),
            style: AppTypography.heroSerif.copyWith(
              color: AppColors.parchment,
              fontSize: 34.sp,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            '${_label(next.key)} · ${_formatDuration(widget.prayerTimes.timeUntilNextPrayer(_now))}',
            style: AppTypography.bodyMedium.copyWith(
              color: const Color(0xFFC9D6CF),
            ),
          ),
        ],
      ),
    );
  }
}
