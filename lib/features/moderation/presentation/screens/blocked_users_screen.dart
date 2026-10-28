import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/motion/motion.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/deen_app_bar.dart';
import '../../../../shared/widgets/islamic_ornaments.dart';
import '../../../../shared/widgets/shimmer_box.dart';
import '../../../groups/domain/entities/group.dart';
import '../../../groups/domain/entities/group_detail.dart';
import '../../../groups/presentation/widgets/snap_widgets.dart';
import '../../domain/entities/blocked_user.dart';
import '../moderation_flows.dart';
import '../providers/moderation_providers.dart';

/// Settings > Blocked users: who the user has blocked, with a way to undo it.
class BlockedUsersScreen extends ConsumerWidget {
  const BlockedUsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(blockedUsersProvider);

    return Scaffold(
      backgroundColor: AppColors.parchment,
      appBar: const DeenAppBar(title: 'Blocked users'),
      body: async.when(
        loading: () => ListView(
          padding: EdgeInsets.all(20.w),
          children: [
            for (var i = 0; i < 3; i++) ...[
              ShimmerBox(
                width: double.infinity,
                height: 68.h,
                borderRadius: 20.r,
              ),
              SizedBox(height: 10.h),
            ],
          ],
        ),
        error: (e, _) => Center(
          child: Padding(
            padding: EdgeInsets.all(32.w),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(e.toString(), textAlign: TextAlign.center),
                SizedBox(height: 12.h),
                FilledButton(
                  onPressed: () => ref.invalidate(blockedUsersProvider),
                  child: const Text('Try again'),
                ),
              ],
            ),
          ),
        ),
        data: (users) => users.isEmpty
            ? const _Empty()
            : ListView(
                padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 32.h),
                children: [
                  Text(
                    'People you block can’t be seen in your groups. They '
                    'aren’t told.',
                    style: TextStyle(
                      fontSize: 13.sp,
                      height: 1.45,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  SizedBox(height: 14.h),
                  for (final u in users) ...[
                    _Row(
                      user: u,
                      onUnblock: () => startUnblock(
                        context,
                        ref,
                        SafetyUser(id: u.userId, name: u.name),
                      ),
                    ),
                    SizedBox(height: 10.h),
                  ],
                ],
              ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final BlockedUser user;
  final VoidCallback onUnblock;
  const _Row({required this.user, required this.onUnblock});

  @override
  Widget build(BuildContext context) {
    final name = user.name.isEmpty ? 'Unknown user' : user.name;
    return Container(
      padding: EdgeInsets.fromLTRB(14.w, 12.h, 10.w, 12.h),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: AppColors.borderWarm),
      ),
      child: Row(
        children: [
          MemberAvatar(
            member: GroupMember(
              userId: user.userId,
              name: name,
              email: '',
              role: GroupRole.member,
              avatarUrl: user.avatarUrl,
            ),
            size: 44.w,
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w700,
                color: AppColors.inkText,
              ),
            ),
          ),
          SizedBox(width: 8.w),
          OutlinedButton(
            onPressed: onUnblock,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.emeraldInk,
              side: BorderSide(
                color: AppColors.emeraldInk.withValues(alpha: 0.6),
              ),
              padding: EdgeInsets.symmetric(horizontal: 14.w),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14.r),
              ),
            ),
            child: Text(
              'Unblock',
              style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 84.w,
              height: 84.w,
              child: CustomPaint(
                painter: StarPainter(
                  fill: AppColors.worshipAccentBg,
                  stroke: AppColors.worshipAccent.withValues(alpha: 0.5),
                  inner: 0.76,
                ),
                child: Icon(
                  Icons.shield_outlined,
                  color: AppColors.worshipAccent,
                  size: 32.sp,
                ),
              ),
            ).slideIn(RevealDirection.top),
            SizedBox(height: 16.h),
            Text(
              'No one is blocked',
              style: TextStyle(
                fontSize: 17.sp,
                fontWeight: FontWeight.w700,
                color: AppColors.inkText,
              ),
            ),
            SizedBox(height: 6.h),
            Text(
              'If someone bothers you in a group, open the ⋯ next to their '
              'name to report or block them.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.sp,
                height: 1.45,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
