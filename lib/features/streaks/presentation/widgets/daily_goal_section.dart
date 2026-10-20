import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/shimmer_box.dart';
import '../providers/streaks_providers.dart';
import 'streak_goal_picker.dart';

/// A group's daily goal on the Rules screen: how many prayers a member must
/// log in a day to keep their streak. Everyone sees it; only the admin can
/// change it.
class DailyGoalSection extends ConsumerWidget {
  final String groupId;
  final bool isAdmin;

  const DailyGoalSection({
    super.key,
    required this.groupId,
    required this.isAdmin,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rule = ref.watch(streakRuleProvider(groupId));
    return rule.when(
      loading: () =>
          ShimmerBox(width: double.infinity, height: 120.h, borderRadius: 22.r),
      error: (_, _) => _Card(
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Couldn’t load this group’s daily goal.',
                style: TextStyle(
                  fontSize: 13.sp,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            TextButton(
              onPressed: () => ref.invalidate(streakRuleProvider(groupId)),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
      data: (r) => _Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 44.w,
                  height: 44.w,
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.local_fire_department_rounded,
                    size: 24.sp,
                    color: AppColors.amber,
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Daily goal',
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        r.summary,
                        style: TextStyle(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w800,
                          color: AppColors.inkText,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 10.h),
            Text(
              isAdmin
                  ? 'As admin you can change this. A change starts tomorrow, so '
                        'no one’s streak breaks today.'
                  : 'Keep your streak by reaching this every day. Only the '
                        'group admin can change it.',
              style: TextStyle(
                fontSize: 12.sp,
                height: 1.4,
                color: AppColors.textSecondary,
              ),
            ),
            if (isAdmin) ...[
              SizedBox(height: 14.h),
              StreakGoalPicker(groupId: groupId, current: r),
            ],
          ],
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(22.r),
        border: Border.all(color: AppColors.borderWarm),
      ),
      child: child,
    );
  }
}
