import '../../../prayer_logs/domain/prayer_log.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/motion/motion.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../shared/widgets/islamic_ornaments.dart';
import '../../domain/entities/group.dart';
import '../../domain/entities/group_detail.dart';
import '../../../streaks/domain/entities/group_streaks.dart';
import 'group_image.dart';
import 'snap_widgets.dart';

/// Compact header: identity + the few facts that matter. Deliberately short so
/// members and activity stay the focus of the screen.
class GroupDetailHero extends StatelessWidget {
  final GroupDetail group;
  final GroupRole myRole;

  /// Opens the invite-link sheet.
  final VoidCallback onInvite;

  /// Opens the group's statistics screen.
  final VoidCallback onOpenStats;

  /// The group's streak board, for today's progress in the header. Null while
  /// loading or if it failed.
  final GroupStreakBoard? board;

  const GroupDetailHero({
    super.key,
    required this.group,
    required this.myRole,
    required this.onInvite,
    required this.onOpenStats,
    this.board,
  });

  @override
  Widget build(BuildContext context) {
    Widget chip(IconData icon, String text, {VoidCallback? onTap}) => Material(
      color: Colors.white.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(14.r),
      child: InkWell(
        borderRadius: BorderRadius.circular(14.r),
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14.r),
            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13.sp, color: AppColors.emeraldInk),
              SizedBox(width: 5.w),
              Text(
                text,
                style: TextStyle(fontSize: 11.sp, color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );

    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: AppColors.heroGradient,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28.r)),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: GeometricPattern(
              color: AppColors.emeraldInk.withValues(alpha: 0.08),
              cell: 52,
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              20.w,
              MediaQuery.of(context).padding.top + 58.h,
              20.w,
              16.h,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (group.avatarUrl != null)
                      GroupImage(
                        path: group.avatarUrl,
                        size: 52.w,
                        radius: 16.r,
                      ).slideIn(RevealDirection.start, distance: 14)
                    else
                      SizedBox(
                        width: 52.w,
                        height: 52.w,
                        child: CustomPaint(
                          painter: StarPainter(
                            fill: AppColors.emeraldInk.withValues(alpha: 0.18),
                            stroke: AppColors.emeraldInk,
                            strokeWidth: 1.4,
                            inner: 0.76,
                          ),
                          child: Icon(
                            Icons.groups_rounded,
                            size: 24.sp,
                            color: AppColors.emeraldInk,
                          ),
                        ),
                      ).slideIn(RevealDirection.start, distance: 14),
                    SizedBox(width: 12.w),
                    Expanded(
                      child:
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                group.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 20.sp,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  height: 1.15,
                                ),
                              ),
                              if (group.description.isNotEmpty) ...[
                                SizedBox(height: 3.h),
                                Text(
                                  group.description,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12.sp,
                                    height: 1.35,
                                    color: AppColors.onHeroSurface.withValues(
                                      alpha: 0.78,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ).slideIn(
                            RevealDirection.bottomStart,
                            delay: const Duration(milliseconds: 60),
                            distance: 12,
                          ),
                    ),
                  ],
                ),
                SizedBox(height: 12.h),
                Wrap(
                  spacing: 8.w,
                  runSpacing: 8.h,
                  children: [
                    chip(
                      Icons.people_alt_rounded,
                      '${group.memberCount} ${group.memberCount == 1 ? 'member' : 'members'}',
                    ),
                    chip(
                      myRole == GroupRole.admin
                          ? Icons.workspace_premium_rounded
                          : Icons.person_rounded,
                      myRole == GroupRole.admin ? 'You’re admin' : 'Member',
                    ),
                    chip(Icons.link_rounded, 'Invite', onTap: onInvite),
                    // The summary below carries its own link; this keeps the
                    // statistics reachable while that summary is not shown.
                    if (board == null || board!.isEmpty)
                      chip(
                        Icons.insights_rounded,
                        'Statistics',
                        onTap: onOpenStats,
                      ),
                  ],
                ).slideIn(
                  RevealDirection.bottom,
                  delay: const Duration(milliseconds: 120),
                  distance: 12,
                ),
                if (board != null && !board!.isEmpty) ...[
                  SizedBox(height: 14.h),
                  _HeroTodaySummary(
                    board: board!,
                    onOpenStats: onOpenStats,
                  ).slideIn(
                    RevealDirection.bottom,
                    delay: const Duration(milliseconds: 180),
                    distance: 12,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// How today is going for the group, on the dark header: how many members
/// have met the daily goal, and the group's longest runs. All from the streak
/// board.
class _HeroTodaySummary extends StatelessWidget {
  final GroupStreakBoard board;
  final VoidCallback onOpenStats;
  const _HeroTodaySummary({required this.board, required this.onOpenStats});

  @override
  Widget build(BuildContext context) {
    final total = board.entries.length;
    final progress = total == 0 ? 0.0 : board.doneToday / total;
    final pct = (progress * 100).round();
    final onHero = AppColors.onHeroSurface;
    final topRun = board.entries.fold<int>(
      0,
      (m, e) => e.currentStreak > m ? e.currentStreak : m,
    );
    final bestEver = board.entries.fold<int>(
      0,
      (m, e) => e.bestStreak > m ? e.bestStreak : m,
    );
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 54.w,
                height: 54.w,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: progress),
                      duration: context.motion.duration(AppMotion.value),
                      curve: AppMotion.entrance,
                      builder: (_, v, _) => CustomPaint(
                        size: Size.square(54.w),
                        painter: RingPainter(
                          progress: v,
                          track: Colors.white.withValues(alpha: 0.18),
                          color: AppColors.emeraldInk,
                          width: 5,
                        ),
                      ),
                    ),
                    Text(
                      '$pct%',
                      style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Goal met today',
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      '${board.doneToday} of $total members',
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: onHero.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  Icon(
                    Icons.local_fire_department_rounded,
                    size: 24.sp,
                    color: AppColors.amber,
                  ),
                  AnimatedCount(
                    value: topRun,
                    fromZero: true,
                    style: TextStyle(
                      fontSize: 17.sp,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1.1,
                    ),
                  ),
                  Text(
                    'top run',
                    style: TextStyle(
                      fontSize: 10.sp,
                      color: onHero.withValues(alpha: 0.75),
                    ),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 10.h),
          Text(
            'Longest streak: $bestEver days',
            style: TextStyle(
              fontSize: 11.sp,
              color: onHero.withValues(alpha: 0.7),
            ),
          ),
          // Everything beyond today's snapshot lives on the statistics screen.
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onOpenStats,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.goldLight,
                padding: EdgeInsets.symmetric(horizontal: 0, vertical: 2.h),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              icon: Icon(Icons.insights_rounded, size: 16.sp),
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'View statistics',
                    style: TextStyle(
                      fontSize: 12.5.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(width: 2.w),
                  Icon(Icons.chevron_right_rounded, size: 16.sp),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A member's row: who they are and, once known, how today and their streak
/// are going. Each figure appears only when it has loaded; with none, the row
/// shows when they joined.
class MemberSnapTile extends StatelessWidget {
  final GroupMember member;
  final int rank;
  final bool isMe;

  /// Whether tapping the row opens the member's details (admin, or self).
  final bool canOpenDetails;
  final VoidCallback onOpenDetails;

  /// Opens the member's latest snap. Only offered while it is unopened.
  final VoidCallback onOpenSnap;

  /// Their latest snap as this viewer sees it (never active on the viewer's
  /// own card).
  final SnapState snapState;

  /// Their streak line (current streak, today's goal), from the board.
  final MemberStreak? streak;

  /// Distinct prayers they have logged today, and the points those earned,
  /// from the group feed. Hidden until the feed has loaded.
  final int? prayersToday;
  final int? pointsToday;

  /// Opens the safety menu (report / block). Null on the viewer's own row.
  final VoidCallback? onMore;

  /// Sends the viewer's own snap to more groups. Only on the viewer's own row,
  /// and only while that is possible.
  final VoidCallback? onAddGroups;

  /// The viewer has blocked this member: their snaps are hidden.
  final bool isBlocked;

  const MemberSnapTile({
    super.key,
    required this.member,
    required this.rank,
    required this.isMe,
    required this.canOpenDetails,
    required this.onOpenDetails,
    required this.onOpenSnap,
    this.snapState = SnapState.none,
    this.streak,
    this.prayersToday,
    this.pointsToday,
    this.onMore,
    this.onAddGroups,
    this.isBlocked = false,
  });

  @override
  Widget build(BuildContext context) {
    final streakLine = streak;
    final hasFigures =
        prayersToday != null || pointsToday != null || streakLine != null;
    return InkWell(
      onTap: canOpenDetails ? onOpenDetails : null,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 11.h),
        child: Row(
          children: [
            SizedBox(
              width: 20.w,
              child: Text(
                '$rank',
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textMuted,
                ),
              ),
            ),
            MemberAvatar(
              member: member,
              size: 44.w,
              ring: streakLine?.todayQualified ?? false,
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          isMe
                              ? '${member.displayName} (you)'
                              : member.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w700,
                            color: AppColors.inkText,
                          ),
                        ),
                      ),
                      SizedBox(width: 6.w),
                      RoleBadge(role: member.role),
                    ],
                  ),
                  SizedBox(height: 3.h),
                  if (hasFigures || isBlocked)
                    // A Wrap, so a long name or large text moves a figure to a
                    // second line instead of overflowing the row.
                    Wrap(
                      spacing: 10.w,
                      runSpacing: 2.h,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (isBlocked) const _BlockedTag(),
                        if (prayersToday != null)
                          _Figure(
                            icon: Icons.check_circle_outline_rounded,
                            color: AppColors.textMuted,
                            text: '$prayersToday/5',
                            label: '$prayersToday of 5 prayers today',
                          ),
                        if (pointsToday != null)
                          _Figure(
                            icon: Icons.bolt_rounded,
                            color: AppColors.amber,
                            text: '$pointsToday',
                            label: '$pointsToday points today',
                          ),
                        if (streakLine != null)
                          _Figure(
                            icon: Icons.local_fire_department_rounded,
                            color: AppColors.amber,
                            text: '${streakLine.currentStreak}d',
                            label: '${streakLine.currentStreak} day streak',
                          ),
                      ],
                    )
                  else
                    Text(joinedLabel(member.joinedAt), style: _meta),
                ],
              ),
            ),
            SizedBox(width: 8.w),
            SnapBox(state: snapState, onTap: onOpenSnap),
            if (onMore != null)
              IconButton(
                tooltip: 'More about ${member.displayName}',
                onPressed: onMore,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: BoxConstraints.tightFor(width: 34.w, height: 40.h),
                icon: Icon(
                  Icons.more_vert_rounded,
                  size: 20.sp,
                  color: AppColors.textMuted,
                ),
              )
            else if (onAddGroups != null)
              IconButton(
                tooltip: 'Send your snap to more groups',
                onPressed: onAddGroups,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: BoxConstraints.tightFor(width: 34.w, height: 40.h),
                icon: Icon(
                  Icons.group_add_rounded,
                  size: 20.sp,
                  color: AppColors.emeraldInk,
                ),
              )
            else
              SizedBox(width: 4.w),
          ],
        ),
      ),
    );
  }

  TextStyle get _meta =>
      TextStyle(fontSize: 11.sp, color: AppColors.textSecondary);
}

/// "Blocked", beside a member's name.
class _BlockedTag extends StatelessWidget {
  const _BlockedTag();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Text(
        'BLOCKED',
        style: TextStyle(
          fontSize: 8.5.sp,
          letterSpacing: 0.8,
          fontWeight: FontWeight.w800,
          color: AppColors.error,
        ),
      ),
    );
  }
}

/// A small icon + number on a member's row.
class _Figure extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  final String label;
  const _Figure({
    required this.icon,
    required this.color,
    required this.text,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13.sp, color: color),
          SizedBox(width: 3.w),
          Text(
            text,
            style: TextStyle(fontSize: 11.sp, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
