import 'package:deen_companion/shared/widgets/shimmer_box.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../providers/hadith_providers.dart';

class HadithOfDayCard extends ConsumerWidget {
  const HadithOfDayCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hadithAsync = ref.watch(dailyHadithNotifierProvider);

    return hadithAsync.when(
      data: (hadith) => GestureDetector(
        onTap: () => context.push('/hadith/detail', extra: hadith),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 16.h),
          decoration: BoxDecoration(
            color: AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(color: AppColors.borderWarm),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'HADITH OF THE DAY',
                style: AppTypography.caption.copyWith(
                  color: AppColors.hadithAccent,
                  letterSpacing: 0.5,
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                hadith.english,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.greetingSerif.copyWith(
                  fontSize: 14.sp,
                  color: AppColors.inkText,
                ),
              ),
              SizedBox(height: 6.h),
              Text(
                '${hadith.collectionName} · ${hadith.hadithNumber}',
                style: AppTypography.caption.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
      loading: () =>
          ShimmerBox(width: double.infinity, height: 110.h, borderRadius: 16.r),
      error: (_, __) =>
          const SizedBox.shrink(), // fail quietly on home — not worth an error card here
    );
  }
}
