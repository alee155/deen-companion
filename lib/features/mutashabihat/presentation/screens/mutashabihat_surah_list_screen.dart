import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/failure_view.dart';
import '../../../../shared/widgets/seal_number_badge.dart';
import '../../../../shared/widgets/shimmer_box.dart';
import '../../domain/entities/mutashabihat_entry.dart';
import '../providers/mutashabihat_providers.dart';
import 'mutashabihat_comparison_screen.dart';
import '../../../../shared/widgets/deen_app_bar.dart';

class MutashabihatSurahListScreen extends ConsumerStatefulWidget {
  final int surah;
  final String surahName;
  const MutashabihatSurahListScreen({
    super.key,
    required this.surah,
    required this.surahName,
  });

  @override
  ConsumerState<MutashabihatSurahListScreen> createState() =>
      _MutashabihatSurahListScreenState();
}

class _MutashabihatSurahListScreenState
    extends ConsumerState<MutashabihatSurahListScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >
          _scrollController.position.maxScrollExtent - 300) {
        ref
            .read(mutashabihatSurahPageNotifierProvider(widget.surah).notifier)
            .loadMore(widget.surah);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pageAsync = ref.watch(
      mutashabihatSurahPageNotifierProvider(widget.surah),
    );

    return Scaffold(
      backgroundColor: AppColors.parchment,
      appBar: DeenAppBar(
        title: widget.surahName,
        subtitle: 'Commonly confused verses',
      ),
      body: pageAsync.when(
        data: (page) {
          if (page.entries.isEmpty) return const _EmptySurah();

          return ListView.builder(
            controller: _scrollController,
            padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 24.h),
            itemCount: page.entries.length + (page.hasMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index >= page.entries.length) {
                return Padding(
                  padding: EdgeInsets.all(20.h),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: AppColors.emeraldInk,
                      strokeWidth: 2.5,
                    ),
                  ),
                );
              }
              return _EntryCard(
                entry: page.entries[index],
              ).slideInAt(index % 8);
            },
          );
        },
        loading: () => const _ListSkeleton(),
        error: (error, _) => Center(
          child: Padding(
            padding: EdgeInsets.all(20.w),
            child: FailureView(
              failure: failureFrom(error),
              onRetry: () async => ref.invalidate(
                mutashabihatSurahPageNotifierProvider(widget.surah),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EntryCard extends StatelessWidget {
  final MutashabihatEntry entry;
  const _EntryCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final verse = entry.verse;
    final count = entry.similarVerses.length;

    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: PressScale(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16.r),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) =>
                    MutashabihatComparisonScreen(entry: entry),
              ),
            ),
            child: Container(
              padding: EdgeInsets.all(14.w),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(color: AppColors.borderWarm),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      SealNumberBadge(number: verse.ayah, size: 32.w),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Text(
                          verse.arabic,
                          textDirection: TextDirection.rtl,
                          textAlign: TextAlign.right,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.arabicBody.copyWith(
                            fontSize: 17.sp,
                            color: AppColors.emeraldInk,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    verse.translation,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.inkText,
                      height: 1.5,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8.w,
                          vertical: 3.h,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.amber.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(20.r),
                        ),
                        child: Text(
                          '$count similar',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.amberDeep,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.textMuted,
                        size: 18.sp,
                      ),
                    ],
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

class _ListSkeleton extends StatelessWidget {
  const _ListSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 24.h),
      itemCount: 6,
      separatorBuilder: (_, __) => SizedBox(height: 12.h),
      itemBuilder: (context, index) => Container(
        padding: EdgeInsets.all(14.w),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: AppColors.borderWarm),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ShimmerBox(width: 32.w, height: 32.w, borderRadius: 10.r),
                SizedBox(width: 12.w),
                Expanded(
                  child: ShimmerBox(
                    width: double.infinity,
                    height: 16.h,
                    borderRadius: 4.r,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12.h),
            ShimmerBox(width: double.infinity, height: 12.h, borderRadius: 4.r),
            SizedBox(height: 6.h),
            ShimmerBox(width: 160.w, height: 12.h, borderRadius: 4.r),
          ],
        ),
      ),
    );
  }
}

class _EmptySurah extends StatelessWidget {
  const _EmptySurah();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(28.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.compare_arrows_rounded,
              size: 36.sp,
              color: AppColors.textMuted,
            ).slideIn(RevealDirection.top, distance: 16),
            SizedBox(height: 12.h),
            Text(
              'Nothing confusable here',
              style: AppTypography.headline.copyWith(
                fontSize: 16.sp,
                color: AppColors.inkText,
              ),
            ).slideIn(
              RevealDirection.bottomStart,
              delay: const Duration(milliseconds: 60),
            ),
            SizedBox(height: 6.h),
            Text(
              'This surah has no verses commonly confused with others. Try '
              'another surah, or shuffle a random pair from the hub.',
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ).slideIn(
              RevealDirection.bottomEnd,
              delay: const Duration(milliseconds: 120),
            ),
          ],
        ),
      ),
    );
  }
}
