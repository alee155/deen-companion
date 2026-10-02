import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/failure_view.dart';
import '../../../../shared/widgets/seal_number_badge.dart';
import '../../../../shared/widgets/shimmer_box.dart';
import '../../domain/entities/islamic_month.dart';
import '../providers/islamic_calendar_providers.dart';
import '../../../../shared/widgets/deen_app_bar.dart';

/// The four months the Quran (9:36) names sacred — fighting was forbidden in
/// them, and they carry weight in Islamic practice beyond an ordinary month.
const Set<int> _sacredMonths = {1, 7, 11, 12};

class IslamicMonthsScreen extends ConsumerWidget {
  const IslamicMonthsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final monthsAsync = ref.watch(islamicMonthsNotifierProvider);

    return Scaffold(
      backgroundColor: AppColors.parchment,
      appBar: const DeenAppBar(
        title: 'Islamic Months',
        subtitle: 'الأشهر الهجرية',
      ),
      body: monthsAsync.when(
        data: (months) => ListView.builder(
          padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 24.h),
          itemCount: months.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) return const _Intro();
            final month = months[index - 1];
            return _MonthCard(
              month: month,
              isSacred: _sacredMonths.contains(month.number),
            ).slideInAt(index - 1);
          },
        ),
        loading: () => const _MonthsSkeleton(),
        error: (error, _) => Center(
          child: Padding(
            padding: EdgeInsets.all(20.w),
            child: FailureView(
              failure: failureFrom(error),
              onRetry: () async =>
                  ref.invalidate(islamicMonthsNotifierProvider),
            ),
          ),
        ),
      ),
    );
  }
}

class _Intro extends StatelessWidget {
  const _Intro();

  @override
  Widget build(BuildContext context) {
    final seq = RevealSequence();
    return Padding(
      padding: EdgeInsets.only(bottom: 16.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'The twelve months of the Hijri year, each roughly 29 or 30 '
            'days — a full year runs about 11 days shorter than the '
            'Gregorian calendar. Four are sacred months, named in the '
            "Quran (9:36).",
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
              height: 1.55,
            ),
          ).slideIn(RevealDirection.bottomStart, delay: seq.next()),
        ],
      ),
    );
  }
}

class _MonthCard extends StatelessWidget {
  final IslamicMonth month;
  final bool isSacred;

  const _MonthCard({required this.month, required this.isSacred});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 10.h),
      child: Container(
        padding: EdgeInsets.all(14.w),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
            color: isSacred
                ? AppColors.gold.withValues(alpha: 0.4)
                : AppColors.borderWarm,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SealNumberBadge(
              number: month.number,
              size: 38.w,
              color: AppColors.emeraldInk,
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          month.nameEnglish,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.titleMedium.copyWith(
                            color: AppColors.inkText,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Text(
                        month.nameArabic,
                        textDirection: TextDirection.rtl,
                        style: AppTypography.arabicBody.copyWith(
                          fontSize: 15.sp,
                          color: AppColors.emeraldInk,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    month.significance,
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                  if (isSacred) ...[
                    SizedBox(height: 8.h),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 8.w,
                        vertical: 3.h,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.goldLight,
                        borderRadius: BorderRadius.circular(20.r),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.auto_awesome_rounded,
                            size: 11.sp,
                            color: AppColors.gold,
                          ),
                          SizedBox(width: 4.w),
                          Text(
                            'Sacred month',
                            style: AppTypography.caption.copyWith(
                              color: AppColors.gold,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthsSkeleton extends StatelessWidget {
  const _MonthsSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 24.h),
      itemCount: 8,
      separatorBuilder: (_, __) => SizedBox(height: 10.h),
      itemBuilder: (context, index) =>
          ShimmerBox(width: double.infinity, height: 84.h, borderRadius: 16.r),
    );
  }
}
