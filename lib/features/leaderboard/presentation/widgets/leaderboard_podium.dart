import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../groups/domain/entities/group_detail.dart';
import '../../domain/entities/leaderboard_entry.dart';
import 'leaderboard_avatar.dart';

/// The top three, first place in the middle and tallest. Needs exactly three
/// entries; with fewer members the screen shows a plain list instead.
class LeaderboardPodium extends StatelessWidget {
  final List<LeaderboardEntry> topThree;
  final GroupDetail? group;
  final String? myId;

  const LeaderboardPodium({
    super.key,
    required this.topThree,
    required this.group,
    required this.myId,
  }) : assert(topThree.length == 3);

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(child: _place(topThree[1], pedestal: 62, avatar: 54)),
        SizedBox(width: 8.w),
        Expanded(child: _place(topThree[0], pedestal: 90, avatar: 66)),
        SizedBox(width: 8.w),
        Expanded(child: _place(topThree[2], pedestal: 46, avatar: 54)),
      ],
    );
  }

  Color _medal(int rank) => switch (rank) {
    1 => AppColors.gold,
    2 => AppColors.textMuted,
    _ => AppColors.amberDeep,
  };

  Widget _place(
    LeaderboardEntry e, {
    required double pedestal,
    required double avatar,
  }) {
    final isMe = e.userId == myId;
    final medal = _medal(e.rank);
    return Semantics(
      label:
          '${e.displayName}${isMe ? ', you' : ''}, rank ${e.rank}, '
          '${e.points} points',
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (e.rank == 1)
            Icon(Icons.workspace_premium_rounded, size: 24.sp, color: medal)
          else
            SizedBox(height: 24.sp),
          SizedBox(height: 4.h),
          LeaderboardAvatar(entry: e, group: group, size: avatar.w, ring: isMe),
          SizedBox(height: 8.h),
          Text(
            isMe ? '${e.displayName} (you)' : e.displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.inkText,
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            '${e.points} pts',
            style: TextStyle(fontSize: 12.sp, color: AppColors.textSecondary),
          ),
          SizedBox(height: 8.h),
          Container(
            height: pedestal.h,
            width: double.infinity,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
              border: Border.all(color: AppColors.borderWarm),
            ),
            child: Column(
              children: [
                // The medal colour, as a strip: a rounded border cannot have
                // a different colour on one side.
                Container(height: 3, color: medal),
                Expanded(
                  child: Center(
                    child: Text(
                      '${e.rank}',
                      style: TextStyle(
                        fontSize: 26.sp,
                        fontWeight: FontWeight.w800,
                        color: medal,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
