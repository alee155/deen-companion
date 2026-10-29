import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/motion/motion.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/feature_hero.dart';
import '../../../../shared/widgets/pinned_hero_bar.dart';
import '../../../../shared/widgets/shimmer_box.dart';
import '../../domain/entities/daily_videos.dart';
import '../providers/videos_providers.dart';
import '../widgets/video_tile.dart';

/// All of today's talks, with the topics as filters.
class VideosScreen extends ConsumerStatefulWidget {
  const VideosScreen({super.key});

  @override
  ConsumerState<VideosScreen> createState() => _VideosScreenState();
}

class _VideosScreenState extends ConsumerState<VideosScreen> {
  // The hero stays put: the bar over it never changes.
  final _bar = ValueNotifier<double>(0);

  /// The topic chosen, or null for all.
  String? _category;

  @override
  void dispose() {
    _bar.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(dailyVideosProvider);
    final daily = async.valueOrNull;

    return Scaffold(
      backgroundColor: AppColors.parchment,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Stack(
          children: [
            Column(
              children: [
                FeatureHero(
                  animate: false,
                  title: 'Bayan of the day',
                  subtitle:
                      'Fresh talks every day. A new set arrives at midnight.',
                  ghostIcon: Icons.play_circle_rounded,
                  chips: [
                    if (daily != null)
                      FeatureHeroChip(
                        Icons.video_library_rounded,
                        '${daily.videos.length} talks',
                      ),
                    if (daily != null && daily.categories.isNotEmpty)
                      FeatureHeroChip(
                        Icons.sell_rounded,
                        '${daily.categories.length} topics',
                      ),
                  ],
                ),
                Expanded(child: _body(async, daily)),
              ],
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: PinnedHeroBar(opacity: _bar, title: 'Bayan of the day'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body(AsyncValue<DailyVideos> async, DailyVideos? daily) {
    if (daily == null) {
      if (async.hasError) {
        final e = async.error;
        return Center(
          child: Padding(
            padding: EdgeInsets.all(32.w),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  e is Failure ? e.message : 'Couldn’t load the videos.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13.sp,
                    color: AppColors.textSecondary,
                  ),
                ),
                SizedBox(height: 12.h),
                FilledButton(
                  onPressed: () => ref.invalidate(dailyVideosProvider),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.emeraldInk,
                    foregroundColor: AppColors.onEmeraldInk,
                  ),
                  child: const Text('Try again'),
                ),
              ],
            ),
          ),
        );
      }
      return ListView(
        padding: EdgeInsets.all(20.w),
        children: [
          for (var i = 0; i < 5; i++) ...[
            ShimmerBox(
              width: double.infinity,
              height: 92.h,
              borderRadius: 20.r,
            ),
            SizedBox(height: 10.h),
          ],
        ],
      );
    }

    final categories = daily.categories;
    final shown = [
      for (final v in daily.videos)
        if (_category == null || v.category == _category) v,
    ];

    return CustomScrollView(
      physics: const ClampingScrollPhysics(),
      slivers: [
        if (categories.length > 1)
          SliverToBoxAdapter(
            child: SizedBox(
              height: 56.h,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.fromLTRB(20.w, 14.h, 20.w, 6.h),
                children: [
                  _FilterChip(
                    label: 'All',
                    selected: _category == null,
                    onTap: () => setState(() => _category = null),
                  ),
                  for (final c in categories)
                    _FilterChip(
                      label: c,
                      selected: _category == c,
                      onTap: () => setState(() => _category = c),
                    ),
                ],
              ),
            ),
          ),
        if (shown.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Text(
                'No talks in this topic today.',
                style: TextStyle(fontSize: 13.sp, color: AppColors.textMuted),
              ),
            ),
          )
        else
          SliverPadding(
            padding: EdgeInsets.fromLTRB(20.w, 10.h, 20.w, 0),
            sliver: SliverList.separated(
              itemCount: shown.length,
              separatorBuilder: (_, _) => SizedBox(height: 10.h),
              itemBuilder: (context, i) => VideoTile(
                video: shown[i],
                onTap: () => context.push('/video/${shown[i].id}'),
              ).slideInAt(i, distance: 18),
            ),
          ),
        SliverToBoxAdapter(
          child: SizedBox(height: MediaQuery.of(context).padding.bottom + 32.h),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(right: 8.w),
    child: Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: Pressable(
        onTap: onTap,
        child: AnimatedContainer(
          duration: context.motion.duration(AppMotion.fast),
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
          decoration: BoxDecoration(
            color: selected ? AppColors.emeraldInk : AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(18.r),
            border: Border.all(
              color: selected ? AppColors.emeraldInk : AppColors.borderWarm,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5.sp,
              fontWeight: FontWeight.w700,
              color: selected
                  ? AppColors.onEmeraldInk
                  : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    ),
  );
}
