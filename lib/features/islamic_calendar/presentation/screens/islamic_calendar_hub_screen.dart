import 'package:deen_companion/features/ads/presentation/widgets/banner_ad_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/failure_view.dart';
import '../../../../shared/widgets/ornament_divider.dart';
import '../../../../shared/widgets/seal_number_badge.dart';
import '../../../../shared/widgets/shimmer_box.dart';
import '../../domain/entities/hijri_conversion.dart';
import '../../domain/entities/islamic_event.dart';
import '../../domain/entities/islamic_month.dart';
import '../providers/hijri_adjustment_provider.dart';
import '../providers/islamic_calendar_providers.dart';
import '../widgets/hijri_adjustment_sheet.dart';
import '../widgets/islamic_event_detail_sheet.dart';
import '../../../../shared/widgets/deen_app_bar.dart';

/// Landing page for the Islamic Calendar: today's Hijri date front and
/// centre, the two tools (converter, months), and what's coming up. Committed
/// to a single accent throughout — [AppColors.emeraldInk] — rather than the
/// mix of teal/gold/orange the previous version borrowed screen to screen.
class IslamicCalendarHubScreen extends ConsumerWidget {
  const IslamicCalendarHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todayAsync = ref.watch(todayHijriNotifierProvider);
    final eventsAsync = ref.watch(islamicEventsNotifierProvider);
    final monthsAsync = ref.watch(islamicMonthsNotifierProvider);

    return Scaffold(
      backgroundColor: AppColors.parchment,
      appBar: const DeenAppBar(
        title: 'Islamic Calendar',
        subtitle: 'التقويم الهجري',
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 28.h),
        children: [
          todayAsync.when(
            data: (today) => _TodayCard(today: today),
            loading: () => ShimmerBox(
              width: double.infinity,
              height: 168.h,
              borderRadius: 20.r,
            ),
            error: (error, _) => FailureView(
              failure: failureFrom(error),
              onRetry: () async => ref.invalidate(todayHijriNotifierProvider),
            ),
          ),
          SizedBox(height: 18.h),
          Row(
            children: [
              Expanded(
                child: _ActionCard(
                  icon: Icons.swap_horiz_rounded,
                  title: 'Date Converter',
                  subtitle: 'Gregorian ⇄ Hijri',
                  onTap: () => context.push('/islamic-calendar/converter'),
                ).slideInAt(0, columns: 2, distance: 20),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: _ActionCard(
                  icon: Icons.calendar_month_outlined,
                  title: 'Islamic Months',
                  subtitle: 'All 12, with meaning',
                  onTap: () => context.push('/islamic-calendar/months'),
                ).slideInAt(1, columns: 2, distance: 20),
              ),
            ],
          ),
          SizedBox(height: 22.h),
          eventsAsync.when(
            data: (bundle) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _NextEventCallout(
                    event: bundle.nextEvent,
                  ).slideIn(RevealDirection.bottom, onVisible: true),
                  SizedBox(height: 22.h),
                  OrnamentDivider(ruleWidth: 26.w),
                  SizedBox(height: 14.h),
                  Row(
                    children: [
                      Icon(
                        Icons.event_available_rounded,
                        size: 16.sp,
                        color: AppColors.emeraldInk,
                      ).slideIn(RevealDirection.topStart, onVisible: true),
                      SizedBox(width: 8.w),
                      Text(
                        'All events this year',
                        style: AppTypography.titleMedium.copyWith(
                          color: AppColors.inkText,
                          fontWeight: FontWeight.w700,
                        ),
                      ).slideIn(
                        RevealDirection.topEnd,
                        delay: const Duration(milliseconds: 60),
                        onVisible: true,
                      ),
                    ],
                  ),
                  SizedBox(height: 10.h),
                  ...monthsAsync.when(
                    data: (months) => bundle.events.asMap().entries.map(
                      (entry) => _EventTile(event: entry.value, months: months)
                          .slideIn(
                            entry.key.isEven
                                ? RevealDirection.start
                                : RevealDirection.end,
                            delay: AppMotion.stagger(entry.key % 8),
                            duration: AppMotion.normal,
                            distance: 22,
                            onVisible: true,
                          ),
                    ),
                    loading: () => [
                      for (var i = 0; i < 3; i++)
                        Padding(
                          padding: EdgeInsets.only(bottom: 10.h),
                          child: ShimmerBox(
                            width: double.infinity,
                            height: 76.h,
                            borderRadius: 16.r,
                          ),
                        ),
                    ],
                    error: (_, _) => const <Widget>[],
                  ),
                ],
              );
            },
            loading: () => Column(
              children: [
                for (var i = 0; i < 4; i++)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 6.h),
                    child: ShimmerBox(
                      width: double.infinity,
                      height: 76.h,
                      borderRadius: 16.r,
                    ),
                  ),
              ],
            ),
            error: (error, _) => Padding(
              padding: EdgeInsets.only(top: 10.h),
              child: FailureView(
                failure: failureFrom(error),
                onRetry: () async =>
                    ref.invalidate(islamicEventsNotifierProvider),
              ),
            ),
          ),
          SizedBox(height: 20.h),
          const BannerAdWidget(margin: EdgeInsets.symmetric(vertical: 4)),
        ],
      ),
    );
  }
}

/// The hero card — today's Gregorian and Hijri date, with the adjustment
/// (Automatic / Pakistan) surfaced as a tappable chip instead of being
/// buried in a settings screen nobody thinks to check.
class _TodayCard extends ConsumerWidget {
  final HijriConversion today;
  const _TodayCard({required this.today});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final adjustment = ref.watch(hijriAdjustmentProvider);
    final seq = RevealSequence();

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.emeraldInk,
            AppColors.emeraldInk.withValues(alpha: 0.82),
          ],
        ),
        borderRadius: BorderRadius.circular(20.r),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            right: -18.w,
            top: -18.h,
            child: Opacity(
              opacity: 0.16,
              child: Transform.rotate(
                angle: 0.18,
                child: Image.asset(
                  'assets/images/calendar_icon.png',
                  width: 110.w,
                  height: 110.w,
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'TODAY',
                style: AppTypography.caption.copyWith(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ).slideIn(
                RevealDirection.topStart,
                distance: 14,
                delay: seq.next(),
              ),
              SizedBox(height: 8.h),
              Text(
                today.hijri.formatted,
                style: AppTypography.heroSerif.copyWith(
                  color: Colors.white,
                  fontSize: 27.sp,
                ),
              ).slideIn(RevealDirection.start, delay: seq.next()),
              SizedBox(height: 4.h),
              Text(
                today.gregorian.formatted,
                style: AppTypography.bodyMedium.copyWith(
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ).slideIn(RevealDirection.bottomStart, delay: seq.next()),
              if (today.note != null) ...[
                SizedBox(height: 10.h),
                Text(
                  today.note!,
                  style: AppTypography.caption.copyWith(
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ).slideIn(RevealDirection.bottom, delay: seq.next()),
              ],
              SizedBox(height: 14.h),
              Pressable(
                scale: AppMotion.pressScaleSmall,
                onTap: () => showHijriAdjustmentSheet(context, ref),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 10.w,
                    vertical: 6.h,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(20.r),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.tune_rounded,
                        size: 13.sp,
                        color: Colors.white,
                      ),
                      SizedBox(width: 6.w),
                      Text(
                        switch (adjustment) {
                          0 => 'Automatic',
                          -1 => 'Pakistan (−1 day)',
                          _ =>
                            'Adjusted ${adjustment > 0 ? '+' : '−'}${adjustment.abs()} day${adjustment.abs() == 1 ? '' : 's'}',
                        },
                        style: AppTypography.caption.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(width: 4.w),
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 14.sp,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ],
                  ),
                ),
              ).slideIn(RevealDirection.bottomEnd, delay: seq.next()),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return PressScale(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16.r),
          child: Container(
            padding: EdgeInsets.all(14.w),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(color: AppColors.borderWarm),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40.w,
                  height: 40.w,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.worshipAccentBg,
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Icon(icon, color: AppColors.emeraldInk, size: 20.sp),
                ),
                SizedBox(height: 10.h),
                Text(
                  title,
                  style: AppTypography.titleMedium.copyWith(
                    color: AppColors.inkText,
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5.sp,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary,
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

class _NextEventCallout extends StatelessWidget {
  final NextIslamicEvent event;
  const _NextEventCallout({required this.event});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.worshipAccentBg,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.emeraldInk.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 40.w,
            height: 40.w,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.emeraldInk.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.star_rounded,
              color: AppColors.emeraldInk,
              size: 20.sp,
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Next: ${event.name}',
                  style: AppTypography.titleMedium.copyWith(
                    color: AppColors.inkText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  event.hijriDateFormatted,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
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

class _EventTile extends StatelessWidget {
  final IslamicEvent event;
  final List<IslamicMonth> months;

  const _EventTile({required this.event, required this.months});

  @override
  Widget build(BuildContext context) {
    final month = months.firstWhere(
      (m) => m.number == event.month,
      orElse: () => months.first,
    );

    return Padding(
      padding: EdgeInsets.only(bottom: 10.h),
      child: PressScale(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16.r),
            onTap: () => showIslamicEventDetailSheet(
              context,
              event: event,
              month: month,
            ),
            child: Container(
              padding: EdgeInsets.all(14.w),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(color: AppColors.borderWarm),
              ),
              child: Row(
                children: [
                  SealNumberBadge(
                    number: event.day,
                    size: 40.w,
                    color: AppColors.emeraldInk,
                  ),
                  SizedBox(width: 14.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          event.name,
                          style: AppTypography.titleMedium.copyWith(
                            color: AppColors.inkText,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          '${event.day} ${month.nameEnglish}',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.emeraldInk,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.textMuted,
                    size: 18.sp,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
