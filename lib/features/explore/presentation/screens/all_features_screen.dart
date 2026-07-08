import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/domain/explore_category.dart';
import '../../../../shared/widgets/coming_soon.dart';
import '../../../home/presentation/widgets/quick_access_grid.dart';

class AllFeaturesScreen extends StatelessWidget {
  const AllFeaturesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final groups = <String, List<ExploreCategory>>{};
    for (final c in ExploreCatalog.all) {
      groups.putIfAbsent(c.group, () => []).add(c);
    }

    return Scaffold(
      backgroundColor: AppColors.parchment,
      appBar: AppBar(
        title: const Text('All features'),
        backgroundColor: AppColors.surfaceLight,
        foregroundColor: AppColors.inkText,
      ),
      body: ListView(
        padding: EdgeInsets.all(20.w),
        children: groups.entries.map((entry) {
          return Padding(
            padding: EdgeInsets.only(bottom: 24.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.key,
                  style: AppTypography.titleMedium.copyWith(
                    color: AppColors.inkText,
                  ),
                ),
                SizedBox(height: 12.h),
                QuickAccessGrid(
                  items: entry.value.map((c) {
                    return QuickAccessItem(
                      label: c.label,
                      icon: c.icon,
                      accentColor: c.accentColor,
                      accentBg: c.accentBg,
                      onTap: () => c.route.isEmpty
                          ? showComingSoonSnackbar(context, c.label)
                          : context.push(c.route),
                    );
                  }).toList(),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
