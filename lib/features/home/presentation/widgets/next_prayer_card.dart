import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/shimmer_box.dart';
import '../../../prayer_times/domain/entities/prayer_times.dart';
import '../../../prayer_times/presentation/providers/prayer_times_provider.dart';

// Gradient mood shifts with the upcoming prayer — dawn tones for Fajr,
// bright gold at midday, warm amber in the afternoon, a sunset wash for
// Maghrib, and deep night for Isha. Purely aesthetic, not functional.
const Map<PrayerName, List<Color>> _prayerGradients = {
  PrayerName.fajr: [Color(0xFF3B4A6B), Color(0xFF6B5B95)],
  PrayerName.dhuhr: [Color(0xFFC98A2E), Color(0xFFE8C77A)],
  PrayerName.asr: [Color(0xFFD9722E), Color(0xFFE8A23C)],
  PrayerName.maghrib: [Color(0xFFB8637A), Color(0xFFD9722E)],
  PrayerName.isha: [Color(0xFF241A11), Color(0xFF3D2B1F)],
};

const Map<PrayerName, IconData> _prayerIcons = {
  PrayerName.fajr: Icons.wb_twilight,
  PrayerName.dhuhr: Icons.wb_sunny_outlined,
  PrayerName.asr: Icons.wb_sunny,
  PrayerName.maghrib: Icons.wb_twilight_outlined,
  PrayerName.isha: Icons.nightlight_round,
};

const Map<PrayerName, String> _prayerLabels = {
  PrayerName.fajr: 'Fajr',
  PrayerName.dhuhr: 'Dhuhr',
  PrayerName.asr: 'Asr',
  PrayerName.maghrib: 'Maghrib',
  PrayerName.isha: 'Isha',
};

class NextPrayerHeroCard extends ConsumerStatefulWidget {
  const NextPrayerHeroCard({super.key});

  @override
  ConsumerState<NextPrayerHeroCard> createState() => _NextPrayerHeroCardState();
}

class _NextPrayerHeroCardState extends ConsumerState<NextPrayerHeroCard> {
  late final Timer _ticker;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(
      const Duration(minutes: 1),
      (_) => setState(() => _now = DateTime.now()),
    );
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

  @override
  Widget build(BuildContext context) {
    final prayerTimesAsync = ref.watch(prayerTimesNotifierProvider);

    return prayerTimesAsync.when(
      data: _buildCard,
      loading: () =>
          ShimmerBox(width: double.infinity, height: 220.h, borderRadius: 20.r),
      error: (error, _) => _buildError(error),
    );
  }

  Widget _buildCard(PrayerTimes prayerTimes) {
    final next = prayerTimes.nextPrayer(_now);
    final timeLeft = prayerTimes.timeUntilNextPrayer(_now);
    final hours = timeLeft.inHours;
    final minutes = timeLeft.inMinutes.remainder(60);
    final gradient = _prayerGradients[next.key]!;

    final entries = [
      MapEntry(PrayerName.fajr, prayerTimes.fajr),
      MapEntry(PrayerName.dhuhr, prayerTimes.dhuhr),
      MapEntry(PrayerName.asr, prayerTimes.asr),
      MapEntry(PrayerName.maghrib, prayerTimes.maghrib),
      MapEntry(PrayerName.isha, prayerTimes.isha),
    ];

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradient,
        ),
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Next prayer · ${_prayerLabels[next.key]}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodyMedium.copyWith(
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 6.h),
                    Text(
                      _formatTime(next.value),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.heroSerif.copyWith(
                        color: Colors.white,
                        fontSize: 32.sp,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      'in ${hours > 0 ? '$hours hour${hours > 1 ? 's' : ''} ' : ''}$minutes minutes',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodyMedium.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 48.w,
                height: 48.w,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Icon(
                  _prayerIcons[next.key],
                  color: Colors.white,
                  size: 22.sp,
                ),
              ),
            ],
          ),
          SizedBox(height: 18.h),
          Container(
            padding: EdgeInsets.only(top: 14.h),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: Colors.white.withOpacity(0.2)),
              ),
            ),
            child: Row(
              children: entries.map((entry) {
                final isActive = entry.key == next.key;
                return Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isActive)
                        Container(
                          width: 4.w,
                          height: 4.w,
                          margin: EdgeInsets.only(bottom: 4.h),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                          ),
                        )
                      else
                        SizedBox(height: 8.h),
                      Icon(
                        _prayerIcons[entry.key],
                        size: 16.sp,
                        color: isActive ? Colors.white : Colors.white70,
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        _prayerLabels[entry.key]!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.caption.copyWith(
                          color: isActive ? Colors.white : Colors.white70,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        _formatShortTime(entry.value),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodyMedium.copyWith(
                          color: Colors.white,
                          fontWeight: isActive
                              ? FontWeight.w700
                              : FontWeight.w400,
                          fontSize: 11.sp,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
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
