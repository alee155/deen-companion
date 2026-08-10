import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/domain/explore_category.dart';
import '../../../../shared/widgets/coming_soon.dart';
import '../../../../shared/widgets/warm_gradient_scaffold.dart';
import '../../../ads/domain/entities/ad_placement_key.dart';
import '../../../ads/presentation/providers/interstitial_ad_coordinator.dart';
import '../../../ads/presentation/widgets/banner_ad_widget.dart';
import '../widgets/explore_category_tile.dart';
import '../../../../shared/widgets/deen_app_bar.dart';

class AllFeaturesScreen extends ConsumerWidget {
  const AllFeaturesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = <String, List<ExploreCategory>>{};
    for (final c in ExploreCatalog.all) {
      groups.putIfAbsent(c.group, () => []).add(c);
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: const DeenAppBar(title: 'Explore', transparent: true),
      extendBodyBehindAppBar: true,
      body: WarmGradientBackground(
        child: SafeArea(
          child: ListView(
            padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 32.h),
            children: [
              ...groups.entries.map((entry) {
                final categories = entry.value;
                return Padding(
                  padding: EdgeInsets.only(bottom: 28.h),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 4.w,
                            height: 16.h,
                            decoration: BoxDecoration(
                              color: categories.first.accentColor,
                              borderRadius: BorderRadius.circular(2.r),
                            ),
                          ),
                          SizedBox(width: 8.w),
                          Text(
                            entry.key,
                            style: AppTypography.titleMedium.copyWith(
                              color: AppColors.inkText,
                            ),
                          ),
                          SizedBox(width: 6.w),
                          Text(
                            '(${categories.length})',
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12.h),
                      ...categories.asMap().entries.map((c) {
                        final index = c.key;
                        final category = c.value;
                        return Padding(
                          padding: EdgeInsets.only(bottom: 10.h),
                          child: ExploreCategoryTile(
                            category: category,
                            onTap: () {
                              if (category.route.isEmpty) {
                                // Nothing to navigate to yet — an
                                // interstitial here would just delay a
                                // "coming soon" message, so it skips the
                                // ad flow entirely.
                                showComingSoonSnackbar(context, category.label);
                                return;
                              }
                              // Every real navigation out of Explore goes
                              // through the shared interstitial rule: the
                              // 1st, 3rd, 5th… tap (across the whole
                              // section, not per category) shows an ad
                              // before the destination opens.
                              ref
                                  .read(interstitialAdCoordinatorProvider)
                                  .showThenRun(
                                    placement: AdPlacementKey.exploreSection,
                                    action: () => context.push(category.route),
                                  );
                            },
                          ).appearStaggered(index),
                        );
                      }),
                    ],
                  ),
                );
              }),
              // A single banner at the bottom of the section — the widget
              // manages its own load/failure/disposal, so this is the
              // entire integration cost per screen.
              const BannerAdWidget(margin: EdgeInsets.only(top: 4, bottom: 12)),
            ],
          ),
        ),
      ),
    );
  }
}
