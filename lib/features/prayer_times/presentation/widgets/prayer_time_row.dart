import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/entities/prayer_times.dart';

class PrayerTimeRow extends StatelessWidget {
  final PrayerTimes prayerTimes;
  const PrayerTimeRow({super.key, required this.prayerTimes});

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

  String _formatTime(DateTime dt) {
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final activeName = prayerTimes.nextPrayer(now).key;
    final times = {
      PrayerName.fajr: prayerTimes.fajr,
      PrayerName.dhuhr: prayerTimes.dhuhr,
      PrayerName.asr: prayerTimes.asr,
      PrayerName.maghrib: prayerTimes.maghrib,
      PrayerName.isha: prayerTimes.isha,
    };

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: times.entries.map((entry) {
        final isActive = entry.key == activeName;
        final color = isActive ? AppColors.emeraldInk : AppColors.textMuted;

        return Column(
          children: [
            if (isActive)
              Container(
                width: 4.w,
                height: 4.w,
                margin: EdgeInsets.only(bottom: 4.h),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.gold,
                ),
              )
            else
              SizedBox(height: 8.h),
            Icon(_icons[entry.key], size: 18.sp, color: color),
            SizedBox(height: 6.h),
            Text(
              _labels[entry.key]!,
              style: AppTypography.caption.copyWith(color: color),
            ),
            SizedBox(height: 2.h),
            Text(
              _formatTime(entry.value),
              style: AppTypography.bodyMedium.copyWith(
                color: color,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        );
      }).toList(),
    );
  }
}
