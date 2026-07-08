import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/shimmer_box.dart';
import '../providers/islamic_calendar_providers.dart';
import '../widgets/islamic_event_tile.dart';

class IslamicCalendarHubScreen extends ConsumerWidget {
  const IslamicCalendarHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todayAsync = ref.watch(todayHijriNotifierProvider);
    final eventsAsync = ref.watch(islamicEventsNotifierProvider);
    final monthsAsync = ref.watch(islamicMonthsNotifierProvider);

    return Scaffold(
      backgroundColor: AppColors.parchment,
      appBar: AppBar(
        title: const Text('Islamic Calendar'),
        backgroundColor: AppColors.surfaceLight,
        foregroundColor: AppColors.inkText,
      ),
      body: ListView(
        padding: EdgeInsets.all(20.w),
        children: [
          todayAsync.when(
            data: (today) => Container(
              padding: EdgeInsets.all(20.w),
              decoration: BoxDecoration(
                color: AppColors.hijriAccent,
                borderRadius: BorderRadius.circular(18.r),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    today.gregorian.formatted,
                    style: AppTypography.bodyMedium.copyWith(
                      color: Colors.white70,
                    ),
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    today.hijri.formatted,
                    style: AppTypography.heroSerif.copyWith(
                      color: Colors.white,
                      fontSize: 26.sp,
                    ),
                  ),
                  if (today.note != null) ...[
                    SizedBox(height: 10.h),
                    Text(
                      today.note!,
                      style: AppTypography.caption.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            loading: () => ShimmerBox(
              width: double.infinity,
              height: 130.h,
              borderRadius: 18.r,
            ),
            error: (error, _) => Text(error.toString()),
          ),
          SizedBox(height: 16.h),

          Row(
            children: [
              Expanded(
                child: _ActionCard(
                  icon: Icons.swap_horiz,
                  label: 'Date Converter',
                  onTap: () => context.push('/islamic-calendar/converter'),
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: _ActionCard(
                  icon: Icons.calendar_month_outlined,
                  label: 'Islamic Months',
                  onTap: () => context.push('/islamic-calendar/months'),
                ),
              ),
            ],
          ),
          SizedBox(height: 20.h),

          eventsAsync.when(
            data: (bundle) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: EdgeInsets.all(16.w),
                    decoration: BoxDecoration(
                      color: AppColors.duasAccentBg,
                      borderRadius: BorderRadius.circular(14.r),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.star_outline,
                          color: AppColors.duasAccent,
                          size: 20.sp,
                        ),
                        SizedBox(width: 10.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Next: ${bundle.nextEvent.name}',
                                style: AppTypography.titleMedium.copyWith(
                                  color: AppColors.inkText,
                                ),
                              ),
                              Text(
                                bundle.nextEvent.hijriDateFormatted,
                                style: AppTypography.bodyMedium.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 16.h),
                  Text(
                    'All events',
                    style: AppTypography.titleMedium.copyWith(
                      color: AppColors.inkText,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  ...monthsAsync.when(
                    data: (months) => bundle.events.map(
                      (e) => IslamicEventTile(event: e, months: months),
                    ),
                    loading: () => [
                      ShimmerBox(
                        width: double.infinity,
                        height: 200.h,
                        borderRadius: 14.r,
                      ),
                    ],
                    error: (_, __) => const <Widget>[],
                  ),
                ],
              );
            },
            loading: () => Column(
              children: List.generate(
                4,
                (i) => Padding(
                  padding: EdgeInsets.symmetric(vertical: 6.h),
                  child: ShimmerBox(
                    width: double.infinity,
                    height: 70.h,
                    borderRadius: 14.r,
                  ),
                ),
              ),
            ),
            error: (error, _) => Text(error.toString()),
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ActionCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14.r),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 16.h),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(color: AppColors.borderWarm),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.hijriAccent, size: 22.sp),
            SizedBox(height: 6.h),
            Text(
              label,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.inkText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
