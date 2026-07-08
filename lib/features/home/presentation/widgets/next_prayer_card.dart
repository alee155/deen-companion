import 'dart:async';
import 'package:deen_companion/shared/widgets/shimmer_box.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../prayer_times/domain/entities/prayer_times.dart';
import '../../../prayer_times/presentation/providers/prayer_times_provider.dart';

class NextPrayerHeroCard extends ConsumerStatefulWidget {
  const NextPrayerHeroCard({super.key});

  @override
  ConsumerState<NextPrayerHeroCard> createState() => _NextPrayerHeroCardState();
}

class _NextPrayerHeroCardState extends ConsumerState<NextPrayerHeroCard> {
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

  String _formatTime(DateTime dt) {
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'pm' : 'am';
    return '$hour:$minute $period';
  }

  String _formatShortTime(DateTime dt) {
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
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
    final prayerTimesAsync = ref.watch(prayerTimesNotifierProvider);

    return prayerTimesAsync.when(
      data: (prayerTimes) => _buildCard(prayerTimes),
      loading: () => _buildSkeleton(),
      error: (error, _) => _buildError(error),
    );
  }

  Widget _buildCard(PrayerTimes prayerTimes) {
    final next = prayerTimes.nextPrayer(_now);
    final timeLeft = prayerTimes.timeUntilNextPrayer(_now);
    final hours = timeLeft.inHours;
    final minutes = timeLeft.inMinutes.remainder(60);

    final entries = [
      MapEntry(PrayerName.fajr, prayerTimes.fajr),
      MapEntry(PrayerName.dhuhr, prayerTimes.dhuhr),
      MapEntry(PrayerName.asr, prayerTimes.asr),
      MapEntry(PrayerName.maghrib, prayerTimes.maghrib),
      MapEntry(PrayerName.isha, prayerTimes.isha),
    ];

    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: AppColors.emeraldInk,
        borderRadius: BorderRadius.circular(18.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Next prayer · ${_label(next.key)}',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.gold,
                    ),
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    _formatTime(next.value),
                    style: AppTypography.heroSerif.copyWith(
                      color: AppColors.parchment,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    'in ${hours > 0 ? '$hours hour${hours > 1 ? 's' : ''} ' : ''}$minutes minutes',
                    style: AppTypography.bodyMedium.copyWith(
                      color: const Color(0xFFC9D6CF),
                    ),
                  ),
                ],
              ),
              Container(
                width: 56.w,
                height: 56.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.gold, width: 2),
                ),
                child: Icon(
                  Icons.explore_outlined,
                  color: AppColors.gold,
                  size: 22.sp,
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          Container(
            padding: EdgeInsets.only(top: 14.h),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: AppColors.gold.withOpacity(0.25)),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: entries.map((entry) {
                final isActive = entry.key == next.key;
                return Column(
                  children: [
                    Text(
                      _label(entry.key),
                      style: AppTypography.caption.copyWith(
                        color: isActive
                            ? AppColors.gold
                            : const Color(0xFF8FA89D),
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      _formatShortTime(entry.value),
                      style: AppTypography.bodyMedium.copyWith(
                        color: isActive
                            ? AppColors.parchment
                            : AppColors.parchment,
                        fontWeight: isActive
                            ? FontWeight.w600
                            : FontWeight.w400,
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

  Widget _buildSkeleton() {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: AppColors.emeraldInk,
        borderRadius: BorderRadius.circular(18.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShimmerBoxDark(width: 120.w, height: 12.h, borderRadius: 4.r),
          SizedBox(height: 14.h),
          ShimmerBoxDark(width: 150.w, height: 32.h, borderRadius: 6.r),
          SizedBox(height: 8.h),
          ShimmerBoxDark(width: 100.w, height: 12.h, borderRadius: 4.r),
          SizedBox(height: 20.h),
          ShimmerBoxDark(
            width: double.infinity,
            height: 44.h,
            borderRadius: 10.r,
          ),
        ],
      ),
    );
  }

  Widget _buildError(Object error) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.hadithAccentBg,
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Column(
        children: [
          Icon(
            Icons.location_off_outlined,
            color: AppColors.hadithAccent,
            size: 22.sp,
          ),
          SizedBox(height: 8.h),
          Text(
            error.toString(),
            textAlign: TextAlign.center,
            style: AppTypography.bodyMedium.copyWith(color: AppColors.inkText),
          ),
          SizedBox(height: 10.h),
          ElevatedButton(
            onPressed: () =>
                ref.read(prayerTimesNotifierProvider.notifier).refresh(),
            child: const Text('Try again'),
          ),
        ],
      ),
    );
  }
}
