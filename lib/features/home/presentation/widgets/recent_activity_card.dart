import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../recent_activity/domain/entities/recent_activity_item.dart';
import '../../../recent_activity/presentation/providers/recent_activity_providers.dart';

/// Replaces the old static "Continue reading" card: shows the single most
/// recent thing the user viewed/played/opened, and takes them straight back
/// to it. Renders nothing until there's at least one real activity to show,
/// rather than pointing at content the user never actually opened.
class RecentActivityCard extends ConsumerWidget {
  const RecentActivityCard({super.key});

  IconData _iconFor(RecentActivityType type) {
    switch (type) {
      case RecentActivityType.surah:
        return Icons.menu_book_outlined;
      case RecentActivityType.hadith:
        return Icons.format_quote;
      case RecentActivityType.dua:
        return Icons.volunteer_activism_outlined;
      case RecentActivityType.asmaName:
        return Icons.auto_awesome_outlined;
      case RecentActivityType.islamicName:
        return Icons.badge_outlined;
      case RecentActivityType.juz:
        return Icons.bookmark_outline;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recentAsync = ref.watch(recentActivityNotifierProvider);
    final items = recentAsync.valueOrNull;

    // Nothing viewed yet — no card, rather than a misleading placeholder.
    if (items == null || items.isEmpty) return const SizedBox.shrink();
    final item = items.first;

    return GestureDetector(
      onTap: () => context.push(item.route),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(color: AppColors.borderWarm),
        ),
        child: Row(
          children: [
            Container(
              width: 36.w,
              height: 36.w,
              decoration: BoxDecoration(
                color: AppColors.quranAccentBg,
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Icon(
                _iconFor(item.type),
                color: AppColors.quranAccent,
                size: 16.sp,
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Recent activity · ${item.type.label}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  SizedBox(height: 1.h),
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.titleMedium.copyWith(
                      color: AppColors.inkText,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: AppColors.textMuted, size: 16.sp),
          ],
        ),
      ),
    );
  }
}
