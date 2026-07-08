import 'package:deen_companion/features/home/presentation/widgets/next_prayer_card.dart';
import 'package:deen_companion/shared/widgets/warm_gradient_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/domain/explore_category.dart';
import '../../../../shared/widgets/coming_soon.dart';
import '../../../hadith/presentation/widgets/hadith_of_day_card.dart';
import '../providers/home_provider.dart';
import '../widgets/continue_reading_card.dart';

import '../widgets/quick_access_grid.dart';
import '../widgets/verse_of_day_card.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = ref.watch(userLocationNameProvider);

    final previewCategories = ExploreCatalog.homePreviewIds
        .map((id) => ExploreCatalog.all.firstWhere((c) => c.id == id))
        .toList();

    return Scaffold(
      backgroundColor: AppColors.parchment,
      body: WarmGradientBackground(
        child: SafeArea(
          child: ListView(
            padding: EdgeInsets.all(20.w),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'As-salamu alaykum',
                        style: AppTypography.greetingSerif.copyWith(
                          color: AppColors.inkText,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        '14 Muharram 1448 · $location',
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    width: 32.w,
                    height: 32.w,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.borderWarm),
                    ),
                    child: Icon(
                      Icons.notifications_none,
                      color: AppColors.inkText,
                      size: 15.sp,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16.h),

              const NextPrayerHeroCard(),
              SizedBox(height: 20.h),

              // Explore — moved right after the hero card, per the new structure.
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
              ),
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

              const VerseOfDayCard(),
              SizedBox(height: 16.h),
              const HadithOfDayCard(),
              SizedBox(height: 20.h),

              ContinueReadingCard(onTap: () {}),
              SizedBox(height: 20.h),
            ],
          ),
        ),
      ),
    );
  }
}
