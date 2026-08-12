import 'package:deen_companion/features/ads/presentation/widgets/banner_ad_widget.dart';
import 'package:deen_companion/features/home/presentation/widgets/next_prayer_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/location/location_service.dart';
import '../../../../core/location/location_status.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../ads/domain/entities/ad_placement_key.dart';
import '../../../ads/presentation/providers/interstitial_ad_coordinator.dart';
import '../../../prayer_times/presentation/providers/prayer_times_provider.dart';
import '../../../../shared/domain/explore_category.dart';
import '../../../../shared/widgets/coming_soon.dart';
import '../../../../shared/widgets/live_clock.dart';
import '../../../../shared/widgets/warm_gradient_scaffold.dart';
import '../../../hadith/presentation/widgets/hadith_of_day_card.dart';
import '../../../islamic_calendar/presentation/providers/islamic_calendar_providers.dart';
import '../providers/home_provider.dart';
import '../widgets/recent_activity_card.dart';

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
                    ).appear(delay: const Duration(milliseconds: 60)),
                    SizedBox(height: 10.h),
                    QuickAccessGrid(
                      items: [
                        ...previewCategories.map((c) {
                          return QuickAccessItem(
                            label: c.label,
                            icon: c.icon,
                            accentColor: c.accentColor,
                            accentBg: c.accentBg,
                            onTap: () {
                              if (c.route.isEmpty) {
                                // Nothing to navigate to yet — same as
                                // Explore's own "coming soon" tiles, this
                                // skips the ad flow entirely rather than
                                // showing an interstitial before a
                                // snackbar.
                                showComingSoonSnackbar(context, c.label);
                                return;
                              }
                              // Same coordinator, same placement key as
                              // Explore → See All (all_features_screen.dart)
                              // — Home's quick-access tiles are just
                              // another entry point into the same set of
                              // destinations, so they share one odd/even
                              // count rather than getting an independent
                              // one. Reusing the placement, not just the
                              // mechanism, is what keeps the frequency
                              // consistent regardless of which route a
                              // user takes to get there.
                              ref
                                  .read(interstitialAdCoordinatorProvider)
                                  .showThenRun(
                                    placement: AdPlacementKey.exploreSection,
                                    action: () => context.push(c.route),
                                  );
                            },
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
                    const BannerAdWidget(
                      margin: EdgeInsets.symmetric(vertical: 4),
                    ),

                    const HadithOfDayCard().appear(
                      delay: const Duration(milliseconds: 160),
                    ),
                    SizedBox(height: 20.h),
                    const RecentActivityCard().appear(
                      delay: const Duration(milliseconds: 200),
                    ),

                    SizedBox(height: 50.h),
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
                      child: GestureDetector(
                        onTap: () => context.push('/profile/settings'),
                        child: todayHijriAsync.when(
                          data: (today) => Text(
                            '${today.hijri.formatted} ⓘ',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          loading: () => Text(
                            'Loading date…',
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppColors.textMuted,
                            ),
                          ),
                          // The Hijri date comes from the network and has
                          // nothing to do with location — when it fails it
                          // gets its own quiet retry affordance instead of
                          // vanishing and leaving the header half-empty.
                          error: (_, _) => GestureDetector(
                            onTap: () =>
                                ref.invalidate(todayHijriNotifierProvider),
                            child: Text(
                              'Date unavailable · Retry',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.bodyMedium.copyWith(
                                color: AppColors.textMuted,
                              ),
                            ),
                          ),
                        ),
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
                _LocationLine(locationAsync: locationAsync),
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

/// The city line under the greeting.
///
/// Three distinct outcomes, three distinct labels: still resolving, resolved
/// (optionally flagged as approximate), or unavailable with a tap target that
/// applies the actual fix. It can no longer sit on "Locating…" forever —
/// the provider behind it always settles.
class _LocationLine extends ConsumerWidget {
  final AsyncValue<LocationLabel> locationAsync;

  const _LocationLine({required this.locationAsync});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mutedStyle = AppTypography.bodyMedium.copyWith(
      color: AppColors.textMuted,
    );

    return locationAsync.when(
      loading: () => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 10.w,
            height: 10.w,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              color: AppColors.textMuted,
            ),
          ),
          SizedBox(width: 6.w),
          Text('Locating…', style: mutedStyle),
        ],
      ),
      error: (_, _) => _ActionableLine(
        label: 'Location unavailable · Retry',
        style: mutedStyle,
        onTap: () => ref.invalidate(currentLocationNameProvider),
      ),
      data: (label) => switch (label) {
        LocationLabelResolved(:final name, :final isApproximate) => Text(
          isApproximate ? '$name · approximate' : name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: mutedStyle,
        ),
        LocationLabelUnavailable(:final kind) => _ActionableLine(
          label: kind.needsSystemSettings
              ? 'Location off · Enable'
              : 'Location unavailable · Fix',
          style: mutedStyle.copyWith(color: AppColors.worshipAccent),
          onTap: () => _resolveLocation(context, ref, kind),
        ),
      },
    );
  }

  Future<void> _resolveLocation(
    BuildContext context,
    WidgetRef ref,
    LocationErrorKind kind,
  ) async {
    final service = ref.read(locationServiceProvider);
    switch (kind) {
      case LocationErrorKind.serviceDisabled:
        await service.openLocationSettings();
      case LocationErrorKind.permissionDeniedForever:
        await service.openAppSettings();
      case LocationErrorKind.permissionDenied:
        await service.requestPermission();
      case LocationErrorKind.timeout:
      case LocationErrorKind.unavailable:
        break;
    }
    ref.invalidate(locationAvailabilityProvider);
    ref.invalidate(currentLocationNameProvider);
    ref.invalidate(prayerTimesNotifierProvider);
  }
}

class _ActionableLine extends StatelessWidget {
  final String label;
  final TextStyle style;
  final VoidCallback onTap;

  const _ActionableLine({
    required this.label,
    required this.style,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: style.copyWith(fontWeight: FontWeight.w600),
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
