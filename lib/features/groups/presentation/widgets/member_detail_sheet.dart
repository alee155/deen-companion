import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../moderation/presentation/providers/moderation_providers.dart';
import '../../../streaks/domain/entities/group_streaks.dart';
import '../../domain/entities/group.dart';
import '../../domain/entities/group_detail.dart';
import 'snap_widgets.dart';

/// What the admin picked inside the member sheet.
enum MemberSheetAction { remove }

/// Opens a member's profile: who they are, their streak and points, and
/// today's prayers. The header always names whose activity is being shown,
/// which matters when an admin browses others.
///
/// [onMore] is the ⋮ in the corner (report or block). It is null on the
/// viewer's own profile, which then has no ⋮.
Future<MemberSheetAction?> showMemberDetailSheet(
  BuildContext context, {
  required GroupMember member,
  required MemberStreak? streak,
  int? pointsToday,
  int? prayersDone,
  required bool isMe,
  required bool viewerIsAdmin,
  Widget? prayerRow,
  VoidCallback? onMore,
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
        prayersDone: prayersDone,
        isMe: isMe,
        viewerIsAdmin: viewerIsAdmin,
        prayerRow: prayerRow,
        onMore: onMore,
      ),
    ),
  );
}

class _MemberDetailSheet extends ConsumerWidget {
  final ScrollController controller;
  final GroupMember member;
  final MemberStreak? streak;
  final int? pointsToday;

  /// How many of today's five prayers they have logged, once the feed has
  /// loaded.
  final int? prayersDone;
  final bool isMe;
  final bool viewerIsAdmin;
  final VoidCallback? onMore;

  /// The member's five prayer circles for today, when the feed has loaded. A
  /// slot rather than a typed field, so this sheet stays free of the
  /// prayer-log feature.
  final Widget? prayerRow;

  const _MemberDetailSheet({
    required this.controller,
    required this.member,
    required this.streak,
    required this.pointsToday,
    required this.prayersDone,
    required this.isMe,
    required this.viewerIsAdmin,
    this.prayerRow,
    this.onMore,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = streak;
    final isBlocked = ref.watch(blockedUserIdsProvider).contains(member.userId);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.parchment,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32.r)),
      ),
      child: Stack(
        children: [
          ListView(
            controller: controller,
            padding: EdgeInsets.fromLTRB(20.w, 10.h, 20.w, 32.h),
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
              SizedBox(height: 18.h),
              _Header(
                member: member,
                isMe: isMe,
                isBlocked: isBlocked,
                ring: s?.todayQualified ?? false,
              ),
              if (viewerIsAdmin && !isMe) ...[
                SizedBox(height: 16.h),
                _AdminNote(name: member.displayName),
              ],
              if (s != null || pointsToday != null) ...[
                SizedBox(height: 20.h),
                _Stats(streak: s, pointsToday: pointsToday),
              ],
              if (prayerRow != null) ...[
                SizedBox(height: 22.h),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Today’s prayers',
                        style: TextStyle(
                          fontSize: 17.sp,
                          fontWeight: FontWeight.w800,
                          color: AppColors.inkText,
                        ),
                      ),
                    ),
                    if (prayersDone != null)
                      Text(
                        '$prayersDone of 5',
                        style: TextStyle(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w700,
                          color: AppColors.emeraldInk,
                        ),
                      ),
                  ],
                ),
                SizedBox(height: 12.h),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: 18.h,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.emeraldInk.withValues(alpha: 0.09),
                    borderRadius: BorderRadius.circular(26.r),
                  ),
                  child: prayerRow!,
                ),
              ],
              // Admin-only, and never on yourself (you'd use "Leave group").
              if (viewerIsAdmin && !isMe) ...[
                SizedBox(height: 26.h),
                SizedBox(
                  height: 52.h,
                  child: TextButton.icon(
                    onPressed: () =>
                        Navigator.of(context).pop(MemberSheetAction.remove),
                    icon: Icon(Icons.person_remove_rounded, size: 19.sp),
                    label: Text(
                      'Remove from group',
                      style: TextStyle(
                        fontSize: 14.5.sp,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.error,
                      backgroundColor: AppColors.error.withValues(alpha: 0.08),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20.r),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          // Report or block: only on someone else's profile.
          if (onMore != null)
            Positioned(
              top: 14.h,
              right: 14.w,
              child: Material(
                color: AppColors.emeraldInk.withValues(alpha: 0.10),
                shape: const CircleBorder(),
                child: IconButton(
                  tooltip: 'More about ${member.displayName}',
                  onPressed: onMore,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints.tightFor(
                    width: 40.w,
                    height: 40.w,
                  ),
                  icon: Icon(
                    Icons.more_vert_rounded,
                    size: 22.sp,
                    color: AppColors.inkText,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The big ringed picture, the name, and one line of who they are.
class _Header extends StatelessWidget {
  final GroupMember member;
  final bool isMe;
  final bool isBlocked;
  final bool ring;
  const _Header({
    required this.member,
    required this.isMe,
    required this.isBlocked,
    required this.ring,
  });

  @override
  Widget build(BuildContext context) {
    final joined = joinedLabel(member.joinedAt);
    return Column(
      children: [
        MemberAvatar(member: member, size: 96.w, ring: ring),
        SizedBox(height: 14.h),
        Text(
          isMe ? '${member.displayName} (You)' : member.displayName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22.sp,
            fontWeight: FontWeight.w800,
            color: AppColors.inkText,
          ),
        ),
        if (member.email.isNotEmpty) ...[
          SizedBox(height: 2.h),
          Text(
            member.email,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13.sp, color: AppColors.textSecondary),
          ),
        ],
        SizedBox(height: 10.h),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8.w,
          runSpacing: 6.h,
          children: [
            if (member.role == GroupRole.admin)
              const RoleBadge(role: GroupRole.admin, soft: true)
            else
              const RoleBadge(role: GroupRole.member),
            if (isBlocked) const _BlockedPill(),
            if (joined.isNotEmpty)
              Text(
                joined,
                style: TextStyle(fontSize: 12.sp, color: AppColors.textMuted),
              ),
          ],
        ),
      ],
    );
  }
}

class _BlockedPill extends StatelessWidget {
  const _BlockedPill();

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
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

/// Tells an admin whose activity they are looking at.
class _AdminNote extends StatelessWidget {
  final String name;
  const _AdminNote({required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: AppColors.emeraldInk.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16.r),
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
              'Admin view · you’re looking at $name’s activity',
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.amberDeep,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Streak, best streak and today's points in one soft card, with fine lines
/// between them.
class _Stats extends StatelessWidget {
  final MemberStreak? streak;
  final int? pointsToday;
  const _Stats({required this.streak, required this.pointsToday});

  @override
  Widget build(BuildContext context) {
    final items = <_StatData>[
      if (streak != null) ...[
        _StatData(
          Icons.local_fire_department_rounded,
          '${streak!.currentStreak}',
          'Day streak',
        ),
        _StatData(
          Icons.emoji_events_rounded,
          '${streak!.bestStreak}',
          'Best streak',
        ),
      ],
      if (pointsToday != null)
        _StatData(Icons.bolt_rounded, '$pointsToday', 'Points today'),
    ];
    return Container(
      padding: EdgeInsets.symmetric(vertical: 18.h),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(26.r),
        border: Border.all(color: AppColors.borderWarm),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0)
                VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: AppColors.borderWarm,
                ),
              Expanded(child: _Stat(items[i])),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatData {
  final IconData icon;
  final String value;
  final String label;
  const _StatData(this.icon, this.value, this.label);
}

class _Stat extends StatelessWidget {
  final _StatData data;
  const _Stat(this.data);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(data.icon, size: 22.sp, color: AppColors.emeraldInk),
        SizedBox(height: 6.h),
        Text(
          data.value,
          style: TextStyle(
            fontSize: 24.sp,
            fontWeight: FontWeight.w800,
            color: AppColors.inkText,
            height: 1.1,
          ),
        ),
        SizedBox(height: 2.h),
        Text(
          data.label,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11.5.sp, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}
