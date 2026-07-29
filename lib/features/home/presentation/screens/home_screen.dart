import 'package:deen_companion/features/home/presentation/widgets/next_prayer_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/domain/explore_category.dart';
import '../../../../shared/widgets/coming_soon.dart';
import '../../../../shared/widgets/live_clock.dart';
import '../../../../shared/widgets/warm_gradient_scaffold.dart';
import '../../../hadith/presentation/widgets/hadith_of_day_card.dart';
import '../../../islamic_calendar/presentation/providers/islamic_calendar_providers.dart';
import '../providers/home_provider.dart';
import '../widgets/continue_reading_card.dart';

import '../widgets/quick_access_grid.dart';
import '../widgets/verse_of_day_card.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  static const double _headerHeight = 110;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final previewCategories = ExploreCatalog.homePreviewIds
        .map((id) => ExploreCatalog.all.firstWhere((c) => c.id == id))
        .toList();

    return Scaffold(
      body: WarmGradientBackground(
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverPersistentHeader(
                pinned: true,
                delegate: _PinnedGreetingHeaderDelegate(
                  height: _headerHeight.h,
                  backgroundColor: AppColors.backgroundGradientStart,
                  child: _GreetingContent(),
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(10.w, 0.h, 10.w, 0.h),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    const NextPrayerHeroCard().appear(),
                    SizedBox(height: 20.h),
                    Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Explore',
                              style: AppTypography.titleMedium.copyWith(
                                color: AppColors.inkText,
                              ),
                            ),
                            GestureDetector(
                              onTap: () => context.push('/explore'),
                              child: Text(
                                'See all',
                                style: AppTypography.bodyMedium.copyWith(
                                  color: AppColors.emeraldInk,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        )
                        .appear(delay: const Duration(milliseconds: 60)),
                    SizedBox(height: 10.h),
                    QuickAccessGrid(
                      items: [
                        ...previewCategories.map((c) {
                          return QuickAccessItem(
                            label: c.label,
                            icon: c.icon,
                            accentColor: c.accentColor,
                            accentBg: c.accentBg,
                            onTap: () => c.route.isEmpty
                                ? showComingSoonSnackbar(context, c.label)
                                : context.push(c.route),
                          );
                        }),
                        QuickAccessItem(
                          label: 'More',
                          icon: Icons.grid_view_rounded,
                          accentColor: AppColors.inkText,
                          accentBg: AppColors.borderWarm,
                          onTap: () => context.push('/explore'),
                        ),
                      ],
                    ),
                    SizedBox(height: 20.h),
                    const VerseOfDayCard().appear(
                      delay: const Duration(milliseconds: 120),
                    ),
                    SizedBox(height: 16.h),
                    const HadithOfDayCard().appear(
                      delay: const Duration(milliseconds: 160),
                    ),
                    SizedBox(height: 20.h),
                    ContinueReadingCard(
                      onTap: () {},
                    ).appear(delay: const Duration(milliseconds: 200)),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GreetingContent extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todayHijriAsync = ref.watch(todayHijriNotifierProvider);
    final locationAsync = ref.watch(currentLocationNameProvider);

    return Padding(
      padding: EdgeInsets.fromLTRB(10.w, 0.h, 10.w, 12.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'As-salamu alaykum',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.greetingSerif.copyWith(
                    color: AppColors.inkText,
                  ),
                ),
                SizedBox(height: 4.h),
                Row(
                  children: [
                    Flexible(
                      child: todayHijriAsync.when(
                        data: (today) => Text(
                          today.hijri.formatted,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        loading: () => Text(
                          '…',
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        error: (_, __) => const SizedBox.shrink(),
                      ),
                    ),
                    Text(
                      '  ·  ',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                    LiveClock(
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 2.h),
                locationAsync.when(
                  data: (loc) => Text(
                    loc,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                  loading: () => Text(
                    'Locating…',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ],
            ),
          ),
          // Container(
          //   width: 42.w,
          //   height: 42.w,
          //   decoration: BoxDecoration(
          //     color: AppColors.surfaceLight,
          //     // shape: BoxShape.circle,
          //     border: Border.all(color: AppColors.borderWarm),
          //   ),
          //   child: Icon(
          //     Icons.notifications_none,
          //     color: AppColors.inkText,
          //     size: 25.sp,
          //   ),
          // ),
        ],
      ),
    );
  }
}

class _PinnedGreetingHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double height;
  final Color backgroundColor;

  _PinnedGreetingHeaderDelegate({
    required this.child,
    required this.height,
    required this.backgroundColor,
  });

  @override
  double get minExtent => height;
  @override
  double get maxExtent => height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: backgroundColor,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: -25.h,
            right: -30.w,
            child: IgnorePointer(
              child: Opacity(
                opacity: 0.3,
                child: Image.asset(
                  'assets/images/top_righ.png',
                  width: 130.w,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),

          Align(alignment: Alignment.topCenter, child: child),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _PinnedGreetingHeaderDelegate oldDelegate) =>
      true;
}
