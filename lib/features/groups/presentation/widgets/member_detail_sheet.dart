import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/group_detail.dart';
import '../../../streaks/domain/entities/group_streaks.dart';
import 'snap_widgets.dart';

/// What the admin picked inside the member sheet.
enum MemberSheetAction { remove }

/// Opens a member's details: today's prayers, their streak and points. The
/// header always names whose activity is being shown, which matters when an
/// admin browses others.
Future<MemberSheetAction?> showMemberDetailSheet(
  BuildContext context, {
  required GroupMember member,
  required MemberStreak? streak,
  int? pointsToday,
  required bool isMe,
  required bool viewerIsAdmin,
  Widget? prayerRow,
}) {
  return showModalBottomSheet<MemberSheetAction>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.86,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (ctx, controller) => _MemberDetailSheet(
        controller: controller,
        member: member,
        streak: streak,
        pointsToday: pointsToday,
        isMe: isMe,
        viewerIsAdmin: viewerIsAdmin,
        prayerRow: prayerRow,
      ),
    ),
  );
}

class _MemberDetailSheet extends StatelessWidget {
  final ScrollController controller;
  final GroupMember member;
  final MemberStreak? streak;
  final int? pointsToday;
  final bool isMe;
  final bool viewerIsAdmin;

  /// The member's five prayer circles for today, when the feed has loaded. A
  /// slot rather than a typed field, so this sheet stays free of the
  /// prayer-log feature.
  final Widget? prayerRow;

  const _MemberDetailSheet({
    required this.controller,
    required this.member,
    required this.streak,
    required this.pointsToday,
    required this.isMe,
    required this.viewerIsAdmin,
    this.prayerRow,
  });

  @override
  Widget build(BuildContext context) {
    final s = streak;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.parchment,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
      ),
      child: ListView(
        controller: controller,
        padding: EdgeInsets.fromLTRB(20.w, 10.h, 20.w, 28.h),
        children: [
          Center(
            child: Container(
              width: 40.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: AppColors.borderWarm,
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
          ),
          SizedBox(height: 16.h),
          Row(
            children: [
              MemberAvatar(
                member: member,
                size: 64.w,
                ring: s?.todayQualified ?? false,
              ),
              SizedBox(width: 14.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isMe ? '${member.displayName} (you)' : member.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 19.sp,
                        fontWeight: FontWeight.w800,
                        color: AppColors.inkText,
                      ),
                    ),
                    if (member.email.isNotEmpty)
                      Text(
                        member.email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    SizedBox(height: 6.h),
                    Row(
                      children: [
                        RoleBadge(role: member.role),
                        SizedBox(width: 8.w),
                        Flexible(
                          child: Text(
                            joinedLabel(member.joinedAt),
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11.sp,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (viewerIsAdmin && !isMe) ...[
            SizedBox(height: 14.h),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 9.h),
              decoration: BoxDecoration(
                color: AppColors.emeraldInk.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(14.r),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.visibility_rounded,
                    size: 16.sp,
                    color: AppColors.amberDeep,
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      'Admin view · you’re looking at '
                      '${member.displayName}’s activity',
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                        color: AppColors.amberDeep,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (prayerRow != null) ...[
            SizedBox(height: 18.h),
            Text('Today’s prayers', style: _sectionStyle),
            SizedBox(height: 10.h),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(20.r),
                border: Border.all(color: AppColors.borderWarm),
              ),
              child: prayerRow!,
            ),
          ],
          if (s != null || pointsToday != null) ...[
            SizedBox(height: 18.h),
            Row(
              children: [
                if (s != null) ...[
                  Expanded(
                    child: StatTile(
                      icon: Icons.local_fire_department_rounded,
                      color: AppColors.amber,
                      value: '${s.currentStreak}',
                      label: 'Day streak',
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: StatTile(
                      icon: Icons.emoji_events_rounded,
                      color: AppColors.gold,
                      value: '${s.bestStreak}',
                      label: 'Best streak',
                    ),
                  ),
                ],
                if (pointsToday != null) ...[
                  if (s != null) SizedBox(width: 10.w),
                  Expanded(
                    child: StatTile(
                      icon: Icons.bolt_rounded,
                      color: AppColors.amber,
                      value: '$pointsToday',
                      label: 'Points today',
                    ),
                  ),
                ],
              ],
            ),
          ],
          // Admin-only, and never on yourself (you'd use "Leave group").
          if (viewerIsAdmin && !isMe) ...[
            SizedBox(height: 22.h),
            SizedBox(
              height: 50.h,
              child: OutlinedButton.icon(
                onPressed: () =>
                    Navigator.of(context).pop(MemberSheetAction.remove),
                icon: Icon(Icons.person_remove_rounded, size: 18.sp),
                label: Text(
                  'Remove from group',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: BorderSide(
                    color: AppColors.error.withValues(alpha: 0.5),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18.r),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  TextStyle get _sectionStyle => TextStyle(
    fontSize: 16.sp,
    fontWeight: FontWeight.w700,
    color: AppColors.inkText,
  );
}
