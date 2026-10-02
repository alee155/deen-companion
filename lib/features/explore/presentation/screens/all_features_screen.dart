import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/motion/motion.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../shared/domain/explore_category.dart';
import '../../../../shared/widgets/coming_soon.dart';
import '../../../../shared/widgets/islamic_ornaments.dart';
import '../../../../shared/widgets/pinned_hero_bar.dart';
import '../../../ads/domain/entities/ad_placement_key.dart';
import '../../../ads/presentation/providers/interstitial_ad_coordinator.dart';
import '../../../ads/presentation/widgets/banner_ad_widget.dart';
import '../widgets/explore_grid_tile.dart';

/// Every feature in the app, grouped by purpose, with live filtering.
class AllFeaturesScreen extends ConsumerStatefulWidget {
  const AllFeaturesScreen({super.key});

  @override
  ConsumerState<AllFeaturesScreen> createState() => _AllFeaturesScreenState();
}

class _AllFeaturesScreenState extends ConsumerState<AllFeaturesScreen> {
  final _search = TextEditingController();
  final _scroll = ScrollController();
  final _bar = ValueNotifier<double>(0);

  static const _groupIcons = {
    'Quran & study': Icons.menu_book_rounded,
    'Knowledge & reflection': Icons.auto_stories_rounded,
    'Worship & time': Icons.mosque_rounded,
    'Tools': Icons.handyman_rounded,
  };

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
    _scroll.addListener(() {
      final t = (_scroll.hasClients ? _scroll.offset / 140 : 0.0).clamp(
        0.0,
        1.0,
      );
      if (t != _bar.value) _bar.value = t;
    });
  }

  @override
  void dispose() {
    _search.dispose();
    _scroll.dispose();
    _bar.dispose();
    super.dispose();
  }

  void _open(ExploreCategory category) {
    HapticFeedback.selectionClick();
    if (category.route.isEmpty) {
      // Nothing to navigate to yet — an interstitial here would just delay
      // a "coming soon" message, so it skips the ad flow entirely.
      showComingSoonSnackbar(context, category.label);
      return;
    }
    // Every real navigation out of Explore goes through the shared
    // interstitial rule: the 1st, 3rd, 5th… tap (across the whole section,
    // not per category) shows an ad before the destination opens.
    ref
        .read(interstitialAdCoordinatorProvider)
        .showThenRun(
          placement: AdPlacementKey.exploreSection,
          action: () => context.push(category.route),
        );
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim().toLowerCase();
    final all = ExploreCatalog.all;
    final matches = all
        .where(
          (c) =>
              query.isEmpty ||
              c.label.toLowerCase().contains(query) ||
              c.description.toLowerCase().contains(query),
        )
        .toList();

    // Preserve the catalog's own order of groups.
    final groups = <String>[];
    for (final c in matches) {
      if (!groups.contains(c.group)) groups.add(c.group);
    }

    var tileIndex = 0;

    return Scaffold(
      backgroundColor: AppColors.parchment,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Stack(
          children: [
            CustomScrollView(
              controller: _scroll,
              physics: const BouncingScrollPhysics(),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              slivers: [
                SliverToBoxAdapter(child: _hero(all.length)),
                if (matches.isEmpty)
                  SliverToBoxAdapter(child: _empty())
                else
                  for (final g in groups) ...[
                    SliverToBoxAdapter(
                      child: _sectionHeader(
                        g,
                        matches.where((c) => c.group == g).length,
                      ),
                    ),
                    SliverPadding(
                      padding: EdgeInsets.symmetric(horizontal: 20.w),
                      sliver: SliverGrid(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          mainAxisSpacing: 16.h,
                          crossAxisSpacing: 4.w,
                          childAspectRatio: 1.0,
                        ),
                        delegate: SliverChildListDelegate([
                          for (final c in matches.where((c) => c.group == g))
                            ExploreGridTile(
                              category: c,
                              onTap: () => _open(c),
                            ).slideInAt(tileIndex++, columns: 3, distance: 18),
                        ]),
                      ),
                    ),
                  ],
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 0),
                    // A single banner at the bottom of the section — the
                    // widget manages its own load/failure/disposal.
                    child: const BannerAdWidget(
                      margin: EdgeInsets.only(top: 4, bottom: 12),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: MediaQuery.of(context).padding.bottom + 24.h,
                  ),
                ),
              ],
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: PinnedHeroBar(opacity: _bar, title: 'Explore'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _hero(int total) {
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.heroSurface, AppColors.emeraldInkDark],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(36.r)),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: GeometricPattern(
              color: AppColors.goldLight.withValues(alpha: 0.08),
              cell: 52,
            ),
          ),
          Positioned(
            right: -26.w,
            top: 46.h,
            child: Icon(
              Icons.explore_rounded,
              size: 170.sp,
              color: AppColors.gold.withValues(alpha: 0.10),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              24.w,
              MediaQuery.of(context).padding.top + 66.h,
              24.w,
              26.h,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Explore',
                  style: TextStyle(
                    fontSize: 32.sp,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    height: 1.1,
                  ),
                ).slideIn(RevealDirection.topStart),
                SizedBox(height: 6.h),
                Text(
                  '$total ways to learn, worship and reflect.',
                  style: TextStyle(
                    fontSize: 13.sp,
                    color: AppColors.onHeroSurface.withValues(alpha: 0.78),
                  ),
                ).slideIn(
                  RevealDirection.start,
                  delay: const Duration(milliseconds: 70),
                ),
                SizedBox(height: 18.h),
                Container(
                  height: 52.h,
                  padding: EdgeInsets.symmetric(horizontal: 14.w),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(18.r),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.search_rounded,
                        size: 20.sp,
                        color: AppColors.goldLight,
                      ),
                      SizedBox(width: 10.w),
                      Expanded(
                        child: TextField(
                          controller: _search,
                          textInputAction: TextInputAction.search,
                          cursorColor: AppColors.gold,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14.sp,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Search features…',
                            hintStyle: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                            ),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            filled: false,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                      if (_search.text.isNotEmpty)
                        Pressable(
                          onTap: _search.clear,
                          scale: AppMotion.pressScaleSmall,
                          child: Icon(
                            Icons.close_rounded,
                            size: 18.sp,
                            color: Colors.white70,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String group, int count) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 26.h, 20.w, 12.h),
      child: Row(
        children: [
          Icon(
            _groupIcons[group] ?? Icons.apps_rounded,
            size: 18.sp,
            color: AppColors.gold,
          ).slideIn(
            RevealDirection.bottomStart,
            onVisible: true,
            duration: AppMotion.normal,
            distance: 16,
          ),
          SizedBox(width: 8.w),
          Expanded(
            child:
                Text(
                  group,
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.inkText,
                  ),
                ).slideIn(
                  RevealDirection.start,
                  onVisible: true,
                  delay: const Duration(milliseconds: 50),
                ),
          ),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 12.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.textMuted,
            ),
          ).slideIn(
            RevealDirection.topEnd,
            onVisible: true,
            delay: const Duration(milliseconds: 100),
            duration: AppMotion.normal,
            distance: 16,
          ),
        ],
      ),
    );
  }

  Widget _empty() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 32.w, vertical: 56.h),
      child: Column(
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 44.sp,
            color: AppColors.textMuted,
          ).slideIn(RevealDirection.top),
          SizedBox(height: 12.h),
          Text(
            'No features match “${_search.text.trim()}”',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14.sp, color: AppColors.textSecondary),
          ).slideIn(RevealDirection.bottom),
        ],
      ),
    );
  }
}
