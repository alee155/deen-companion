import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/motion/motion.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../shared/widgets/islamic_ornaments.dart';
import '../../domain/entities/group.dart';
import '../../domain/entities/group_detail.dart';
import '../../domain/entities/member_snap_stats.dart';
import 'snap_widgets.dart';

/// Compact header: identity + the few facts that matter. Deliberately short so
/// members and activity stay the focus of the screen.
class GroupDetailHero extends StatelessWidget {
  final GroupDetail group;
  final GroupRole myRole;

  /// Opens the invite-link sheet.
  final VoidCallback onInvite;

  const GroupDetailHero({
    super.key,
    required this.group,
    required this.myRole,
    required this.onInvite,
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
          colors: [AppColors.heroSurface, AppColors.emeraldInkDark],
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
                  ],
                ).slideIn(
                  RevealDirection.bottom,
                  delay: const Duration(milliseconds: 120),
                  distance: 12,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Today's progress, streak and the week, in one light card.
class SnapOverviewCard extends StatelessWidget {
  final GroupSnapOverview overview;
  const SnapOverviewCard({super.key, required this.overview});

  @override
  Widget build(BuildContext context) {
    final pct = (overview.todayProgress * 100).round();
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: AppColors.borderWarm),
      ),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 64.w,
                height: 64.w,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: overview.todayProgress),
                      duration: context.motion.duration(AppMotion.value),
                      curve: AppMotion.entrance,
                      builder: (_, v, _) => CustomPaint(
                        size: Size.square(64.w),
                        painter: RingPainter(
                          progress: v,
                          track: AppColors.worshipAccent.withValues(
                            alpha: 0.15,
                          ),
                          color: AppColors.emeraldInk,
                          width: 6,
                        ),
                      ),
                    ),
                    Text(
                      '$pct%',
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w800,
                        color: AppColors.inkText,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 14.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Snapped today',
                      style: TextStyle(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w700,
                        color: AppColors.inkText,
                      ),
                    ),
                    SizedBox(height: 3.h),
                    Text(
                      '${overview.snappedTodayCount} of ${overview.memberCount} members',
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  Icon(
                    Icons.local_fire_department_rounded,
                    size: 26.sp,
                    color: AppColors.amber,
                  ),
                  AnimatedCount(
                    value: overview.currentStreak,
                    fromZero: true,
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w800,
                      color: AppColors.inkText,
                      height: 1.1,
                    ),
                  ),
                  Text(
                    'day streak',
                    style: TextStyle(
                      fontSize: 10.sp,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 14.h),
          Row(
            children: [
              for (final d in overview.week)
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        _dayLetter(d.date.weekday),
                        style: TextStyle(
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textMuted,
                        ),
                      ),
                      SizedBox(height: 5.h),
                      Container(
                        width: 26.w,
                        height: 26.w,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: d.completed
                              ? AppColors.emeraldInk
                              : AppColors.parchment,
                          border: d.isToday && !d.completed
                              ? Border.all(
                                  color: AppColors.emeraldInk,
                                  width: 1.6,
                                )
                              : null,
                        ),
                        child: d.completed
                            ? Icon(
                                Icons.check_rounded,
                                size: 15.sp,
                                color: AppColors.onEmeraldInk,
                              )
                            : null,
                      ),
                    ],
                  ),
                ),
            ],
          ),
          SizedBox(height: 10.h),
          Text(
            'Longest streak: ${overview.longestStreak} days',
            style: TextStyle(fontSize: 11.sp, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  static String _dayLetter(int weekday) => 'MTWTFSS'[weekday - 1];
}

/// A leaderboard row. [stats] is null while loading or if stats failed; the
/// row then shows identity only.
class MemberSnapTile extends StatelessWidget {
  final GroupMember member;
  final MemberSnapStats? stats;
  final int rank;
  final bool isMe;

  /// Whether tapping the row opens the member's details (admin, or self).
  final bool canOpenDetails;
  final VoidCallback onOpenDetails;
  final VoidCallback onOpenSnap;

  const MemberSnapTile({
    super.key,
    required this.member,
    required this.stats,
    required this.rank,
    required this.isMe,
    required this.canOpenDetails,
    required this.onOpenDetails,
    required this.onOpenSnap,
  });

  @override
  Widget build(BuildContext context) {
    final s = stats;
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
              ring: s?.snappedToday ?? false,
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
                  if (s != null)
                    Row(
                      children: [
                        Icon(
                          Icons.photo_camera_rounded,
                          size: 12.sp,
                          color: AppColors.textMuted,
                        ),
                        SizedBox(width: 3.w),
                        Text('${s.totalSnaps}', style: _meta),
                        SizedBox(width: 10.w),
                        Icon(
                          Icons.bolt_rounded,
                          size: 13.sp,
                          color: AppColors.amber,
                        ),
                        Text('${s.score}', style: _meta),
                        SizedBox(width: 10.w),
                        Icon(
                          Icons.local_fire_department_rounded,
                          size: 13.sp,
                          color: AppColors.amber,
                        ),
                        Text('${s.streakDays}d', style: _meta),
                      ],
                    )
                  else
                    Text(joinedLabel(member.joinedAt), style: _meta),
                ],
              ),
            ),
            SizedBox(width: 8.w),
            SnapIconButton(snap: s?.latestSnap, onTap: onOpenSnap),
            if (canOpenDetails) ...[
              SizedBox(width: 4.w),
              Icon(
                Icons.chevron_right_rounded,
                size: 20.sp,
                color: AppColors.textMuted,
              ),
            ],
          ],
        ),
      ),
    );
  }

  TextStyle get _meta =>
      TextStyle(fontSize: 11.sp, color: AppColors.textSecondary);
}
