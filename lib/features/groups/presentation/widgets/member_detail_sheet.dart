import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/group_detail.dart';
import '../../domain/entities/member_snap_stats.dart';
import 'snap_widgets.dart';

/// Opens a member's detailed profile + snap activity. The header always names
/// whose activity is being shown, which matters when an admin browses others.
/// What the admin picked inside the member sheet.
enum MemberSheetAction { remove }

Future<MemberSheetAction?> showMemberDetailSheet(
  BuildContext context, {
  required GroupMember member,
  required MemberSnapStats? stats,
  required bool isMe,
  required bool viewerIsAdmin,
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
        stats: stats,
        isMe: isMe,
        viewerIsAdmin: viewerIsAdmin,
      ),
    ),
  );
}

class _MemberDetailSheet extends StatelessWidget {
  final ScrollController controller;
  final GroupMember member;
  final MemberSnapStats? stats;
  final bool isMe;
  final bool viewerIsAdmin;

  const _MemberDetailSheet({
    required this.controller,
    required this.member,
    required this.stats,
    required this.isMe,
    required this.viewerIsAdmin,
  });

  @override
  Widget build(BuildContext context) {
    final s = stats;
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
                ring: s?.snappedToday ?? false,
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
          SizedBox(height: 18.h),
          if (s == null)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 32.h),
              child: Center(
                child: Text(
                  'Snap activity isn’t available right now.',
                  style: TextStyle(
                    fontSize: 13.sp,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            )
          else ...[
            Row(
              children: [
                Expanded(
                  child: StatTile(
                    icon: Icons.photo_camera_rounded,
                    color: AppColors.worshipAccent,
                    value: '${s.totalSnaps}',
                    label: 'Snaps',
                  ),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: StatTile(
                    icon: Icons.bolt_rounded,
                    color: AppColors.amber,
                    value: '${s.score}',
                    label: 'Score',
                  ),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: StatTile(
                    icon: Icons.local_fire_department_rounded,
                    color: AppColors.amber,
                    value: '${s.streakDays}',
                    label: 'Day streak',
                  ),
                ),
              ],
            ),
            SizedBox(height: 18.h),
            Row(
              children: [
                Expanded(child: Text('Snap activity', style: _sectionStyle)),
                const PreviewBadge(),
              ],
            ),
            SizedBox(height: 10.h),
            Container(
              padding: EdgeInsets.fromLTRB(14.w, 16.h, 14.w, 12.h),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(20.r),
                border: Border.all(color: AppColors.borderWarm),
              ),
              child: ActivityBarChart(values: s.dailyActivity),
            ),
            SizedBox(height: 18.h),
            Row(
              children: [
                Expanded(child: Text('Recent snaps', style: _sectionStyle)),
                const PreviewBadge(),
              ],
            ),
            SizedBox(height: 10.h),
            SizedBox(
              height: 118.h,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: s.recentSnaps.length,
                separatorBuilder: (_, _) => SizedBox(width: 10.w),
                itemBuilder: (_, i) => _SnapThumb(
                  snap: s.recentSnaps[i],
                  onTap: () => showSnapViewer(
                    context,
                    member: member,
                    snap: s.recentSnaps[i],
                  ),
                ),
              ),
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

class _SnapThumb extends StatelessWidget {
  final SnapItem snap;
  final VoidCallback onTap;
  const _SnapThumb({required this.snap, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 86.w,
        padding: EdgeInsets.all(8.w),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18.r),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.heroSurface, AppColors.emeraldInkDark],
          ),
          border: Border.all(
            color: snap.viewed ? AppColors.borderWarm : AppColors.emeraldInk,
            width: 1.6,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(
              Icons.menu_book_rounded,
              size: 26.sp,
              color: AppColors.emeraldInk,
            ),
            Text(
              snap.caption ?? 'Snap',
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 10.sp, color: Colors.white),
            ),
            Text(
              timeAgo(snap.sentAt),
              style: TextStyle(
                fontSize: 9.sp,
                color: AppColors.onHeroSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Full-screen, Snapchat-style viewer. Auto-closes after a few seconds; tap
/// anywhere to dismiss. Content is a placeholder until real snaps exist.
Future<void> showSnapViewer(
  BuildContext context, {
  required GroupMember member,
  required SnapItem snap,
}) {
  HapticFeedback.selectionClick();
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close snap',
    barrierColor: Colors.black,
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (_, _, _) => _SnapViewer(member: member, snap: snap),
  );
}

class _SnapViewer extends StatefulWidget {
  final GroupMember member;
  final SnapItem snap;
  const _SnapViewer({required this.member, required this.snap});

  @override
  State<_SnapViewer> createState() => _SnapViewerState();
}

class _SnapViewerState extends State<_SnapViewer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _progress = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  );

  @override
  void initState() {
    super.initState();
    _progress.forward().whenComplete(() {
      if (mounted) Navigator.of(context).maybePop();
    });
  }

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.of(context).maybePop(),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AppColors.heroSurface, AppColors.emeraldInkDark],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.all(16.w),
              child: Column(
                children: [
                  AnimatedBuilder(
                    animation: _progress,
                    builder: (_, _) => ClipRRect(
                      borderRadius: BorderRadius.circular(2.r),
                      child: LinearProgressIndicator(
                        value: _progress.value,
                        minHeight: 3.h,
                        backgroundColor: Colors.white.withValues(alpha: 0.25),
                        color: AppColors.emeraldInk,
                      ),
                    ),
                  ),
                  SizedBox(height: 12.h),
                  Row(
                    children: [
                      MemberAvatar(member: widget.member, size: 38.w),
                      SizedBox(width: 10.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.member.displayName,
                              style: TextStyle(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              timeAgo(widget.snap.sentAt),
                              style: TextStyle(
                                fontSize: 11.sp,
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close',
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(Icons.close_rounded),
                        color: Colors.white,
                      ),
                    ],
                  ),
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.menu_book_rounded,
                            size: 84.sp,
                            color: AppColors.emeraldInk,
                          ),
                          SizedBox(height: 18.h),
                          Text(
                            widget.snap.caption ?? 'Snap',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 22.sp,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 10.h),
                          Text(
                            'Sample snap — real snaps arrive with the snaps feature',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: Colors.white.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
