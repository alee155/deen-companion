import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/domain/explore_category.dart';
import '../../../../shared/widgets/coming_soon.dart';
import '../../../../shared/widgets/warm_gradient_scaffold.dart';
import '../widgets/explore_category_tile.dart';
import '../../../../shared/widgets/deen_app_bar.dart';

class AllFeaturesScreen extends StatelessWidget {
  const AllFeaturesScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
            children: groups.entries.map((entry) {
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
                          onTap: () => category.route.isEmpty
                              ? showComingSoonSnackbar(context, category.label)
                              : context.push(category.route),
                        ).appearStaggered(index),
                      );
                    }),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}
