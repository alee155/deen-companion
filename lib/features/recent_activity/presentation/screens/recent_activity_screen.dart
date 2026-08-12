import 'package:deen_companion/features/ads/presentation/widgets/banner_ad_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../domain/entities/recent_activity_item.dart';
import '../providers/recent_activity_providers.dart';

class RecentActivityScreen extends ConsumerWidget {
  const RecentActivityScreen({super.key});

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

  String _timeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recentAsync = ref.watch(recentActivityNotifierProvider);

    return Scaffold(
      backgroundColor: AppColors.parchment,
      body: SafeArea(
        child: recentAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (_, __) => Center(
            child: Text(
              'Could not load recent activity.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          data: (items) {
            return ListView(
              padding: EdgeInsets.all(20.w),
              children: [
                Text(
                  'Recent Activity',
                  style: TextStyle(
                    fontSize: 22.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.inkText,
                  ),
                ),
                SizedBox(height: 20.h),
                const BannerAdWidget(margin: EdgeInsets.symmetric(vertical: 4)),

                if (items.isEmpty)
                  Container(
                    padding: EdgeInsets.all(24.w),
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(14.r),
                      border: Border.all(color: AppColors.borderWarm),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.history,
                          size: 32.sp,
                          color: AppColors.textMuted,
                        ),
                        SizedBox(height: 10.h),
                        Text(
                          'What you read, play, or open will show up here — '
                          'your last 5 activities.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13.sp,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ...items.asMap().entries.map(
                    (entry) => Padding(
                      padding: EdgeInsets.only(bottom: 10.h),
                      child: _RecentTile(
                        item: entry.value,
                        icon: _iconFor(entry.value.type),
                        timeLabel: _timeAgo(entry.value.viewedAt),
                        onTap: () => context.push(entry.value.route),
                      ).appearStaggered(entry.key),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _RecentTile extends StatelessWidget {
  final RecentActivityItem item;
  final IconData icon;
  final String timeLabel;
  final VoidCallback onTap;

  const _RecentTile({
    required this.item,
    required this.icon,
    required this.timeLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14.r),
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.all(14.w),
          decoration: BoxDecoration(
            color: AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(14.r),
            border: Border.all(color: AppColors.borderWarm),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20.sp, color: AppColors.emeraldInk),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                        color: AppColors.inkText,
                      ),
                    ),
                    if (item.subtitle != null) ...[
                      SizedBox(height: 2.h),
                      Text(
                        item.subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Text(
                timeLabel,
                style: TextStyle(fontSize: 11.sp, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
