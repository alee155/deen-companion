import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../groups/domain/entities/group.dart';
import '../../../groups/domain/entities/group_detail.dart';
import '../../../groups/presentation/widgets/snap_widgets.dart';
import '../../domain/entities/leaderboard_entry.dart';
import 'leaderboard_avatar.dart';

/// The ranked members as one card, a row each. Your own row is tinted.
class LeaderboardRows extends StatelessWidget {
  final List<LeaderboardEntry> entries;
  final GroupDetail? group;
  final String? myId;

  const LeaderboardRows({
    super.key,
    required this.entries,
    required this.group,
    required this.myId,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: AppColors.borderWarm),
      ),
      child: Column(
        children: [
          for (final (i, e) in entries.indexed) ...[
            _Row(entry: e, group: group, isMe: e.userId == myId),
            if (i != entries.length - 1)
              Divider(height: 1, indent: 72.w, color: AppColors.borderWarm),
          ],
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final LeaderboardEntry entry;
  final GroupDetail? group;
  final bool isMe;

  const _Row({required this.entry, required this.group, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final e = entry;
    final prayers =
        '${e.prayersLogged} ${e.prayersLogged == 1 ? 'prayer' : 'prayers'}';
    return Semantics(
      label:
          '${e.displayName}${isMe ? ', you' : ''}, rank ${e.rank}, '
          '${e.points} points, $prayers logged, '
          '${e.currentStreak} day streak',
      excludeSemantics: true,
      child: Container(
        color: isMe ? AppColors.gold.withValues(alpha: 0.12) : null,
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
        child: Row(
          children: [
            SizedBox(
              width: 28.w,
              child: Text(
                '${e.rank}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            SizedBox(width: 10.w),
            LeaderboardAvatar(entry: e, group: group, size: 42.w, ring: isMe),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          isMe ? '${e.displayName} (you)' : e.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w700,
                            color: AppColors.inkText,
                          ),
                        ),
                      ),
                      if (e.role == GroupRole.admin) ...[
                        SizedBox(width: 6.w),
                        RoleBadge(role: e.role),
                      ],
                    ],
                  ),
                  SizedBox(height: 3.h),
                  Row(
                    children: [
                      Text(
                        prayers,
                        style: TextStyle(
                          fontSize: 11.5.sp,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Icon(
                        Icons.local_fire_department_rounded,
                        size: 13.sp,
                        color: e.currentStreak > 0
                            ? AppColors.amber
                            : AppColors.textMuted,
                      ),
                      SizedBox(width: 2.w),
                      Text(
                        '${e.currentStreak}d',
                        style: TextStyle(
                          fontSize: 11.5.sp,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(width: 8.w),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${e.points}',
                  style: TextStyle(
                    fontSize: 17.sp,
                    fontWeight: FontWeight.w800,
                    color: AppColors.inkText,
                  ),
                ),
                Text(
                  'pts',
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
