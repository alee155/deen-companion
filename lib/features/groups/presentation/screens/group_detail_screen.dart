import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/motion/motion.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../shared/widgets/pinned_hero_bar.dart';
import '../../../../shared/widgets/shimmer_box.dart';
import '../../../auth/presentation/providers/auth_session_provider.dart';
import '../../../prayer_logs/presentation/providers/prayer_logs_providers.dart';
import '../../../prayer_logs/presentation/widgets/group_prayers_section.dart';
import '../../domain/entities/group_detail.dart';
import '../../domain/entities/member_snap_stats.dart';
import '../providers/groups_providers.dart';
import '../widgets/delete_group_sheet.dart';
import '../widgets/edit_group_sheet.dart';
import '../widgets/group_detail_widgets.dart';
import '../widgets/invite_group_sheet.dart';
import '../widgets/leave_group_sheet.dart';
import '../widgets/manage_group_sheet.dart';
import '../widgets/remove_member_sheet.dart';
import '../widgets/member_detail_sheet.dart';
import '../widgets/snap_widgets.dart';

/// Pushed as a top-level route, so the bottom navigation bar is not shown.
///
/// Group info and members come from the API; snap numbers are sample data
/// behind [snapStatsRepositoryProvider] until that backend exists.
class GroupDetailScreen extends ConsumerStatefulWidget {
  final String groupId;
  const GroupDetailScreen({super.key, required this.groupId});

  @override
  ConsumerState<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends ConsumerState<GroupDetailScreen> {
  final _scroll = ScrollController();
  final _bar = ValueNotifier<double>(0);

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      final t = (_scroll.hasClients ? _scroll.offset / 100 : 0.0).clamp(
        0.0,
        1.0,
      );
      if (t != _bar.value) _bar.value = t;
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    _bar.dispose();
    super.dispose();
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(behavior: SnackBarBehavior.floating, content: Text(message)),
      );
  }

  /// Admin-only manage menu → edit / invite / delete.
  Future<void> _showGroupMenu(GroupDetail group) async {
    final action = await showManageGroupSheet(
      context,
      group,
      isAdmin: group.isAdmin(ref.read(authSessionProvider).userId),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case ManageAction.edit:
        final saved = await showEditGroupSheet(context, group);
        if (saved == true && mounted) _toast('Group updated');
      case ManageAction.invite:
        await showInviteGroupSheet(
          context,
          group: group,
          isAdmin: group.isAdmin(ref.read(authSessionProvider).userId),
        );
      case ManageAction.leave:
        await _leave(group);
      case ManageAction.delete:
        await _delete(group);
    }
  }

  Future<void> _leave(GroupDetail group) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final left = await showLeaveGroupSheet(
      context,
      group: group,
      isAdmin: group.isAdmin(ref.read(authSessionProvider).userId),
    );
    if (left != true || !mounted) return;
    navigator.pop();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text('You left “${group.name}”'),
      ),
    );
  }

  Future<void> _removeMember(GroupDetail group, GroupMember member) async {
    final removed = await showRemoveMemberSheet(
      context,
      group: group,
      member: member,
    );
    if (removed == true && mounted) {
      _toast('${member.displayName} was removed');
    }
  }

  Future<void> _delete(GroupDetail group) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final deleted = await showDeleteGroupSheet(context, group);
    if (deleted != true || !mounted) return;
    navigator.pop();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text('“${group.name}” deleted'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(groupDetailProvider(widget.groupId));
    final myId = ref.watch(authSessionProvider).userId;
    final group = async.valueOrNull;
    final isAdmin = group?.isAdmin(myId) ?? false;

    return Scaffold(
      backgroundColor: AppColors.parchment,
      floatingActionButton: group == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () async {
                HapticFeedback.selectionClick();
                final sent = await context.push<bool>(
                  '/groups/${group.id}/snap',
                );
                if (sent == true && mounted) _toast('Snap sent');
              },
              backgroundColor: AppColors.emeraldInk,
              foregroundColor: AppColors.onEmeraldInk,
              icon: const Icon(Icons.camera_alt_rounded),
              label: Text(
                'Send snap',
                style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w800),
              ),
            ),
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Stack(
          children: [
            async.when(
              data: (g) => _content(g, myId, isAdmin),
              loading: () => Center(
                child: CircularProgressIndicator(color: AppColors.emeraldInk),
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
                        onPressed: () =>
                            ref.invalidate(groupDetailProvider(widget.groupId)),
                        child: const Text('Try again'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: PinnedHeroBar(
                opacity: _bar,
                title: group?.name ?? 'Group',
                // Everyone gets options (invite / leave); edit and delete are
                // only offered to the admin inside.
                trailingIcon: group == null ? null : Icons.more_horiz_rounded,
                trailingTooltip: 'Group options',
                onTrailing: group == null ? null : () => _showGroupMenu(group),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _content(GroupDetail g, String? myId, bool isAdmin) {
    final overviewAsync = ref.watch(groupSnapOverviewProvider(g.id));
    final overview = overviewAsync.valueOrNull;

    // Leaderboard order: highest score first once stats are known.
    final members = [...g.members];
    if (overview != null) {
      members.sort(
        (a, b) => (overview.members[b.userId]?.score ?? 0).compareTo(
          overview.members[a.userId]?.score ?? 0,
        ),
      );
    }

    return RefreshIndicator(
      edgeOffset: 90.h,
      onRefresh: () async {
        ref.invalidate(groupDetailProvider(g.id));
        ref.invalidate(groupPrayersProvider);
        await ref.read(groupDetailProvider(g.id).future);
      },
      child: CustomScrollView(
        controller: _scroll,
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          SliverToBoxAdapter(
            child: GroupDetailHero(
              group: g,
              myRole: g.roleOf(myId),
              onInvite: () =>
                  showInviteGroupSheet(context, group: g, isAdmin: isAdmin),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(20.w, 18.h, 20.w, 0),
            sliver: SliverToBoxAdapter(
              child: GroupPrayersSection(groupId: g.id),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(20.w, 18.h, 20.w, 0),
            sliver: SliverToBoxAdapter(
              child: overview != null
                  ? SnapOverviewCard(overview: overview).slideIn(
                      RevealDirection.bottomStart,
                      delay: const Duration(milliseconds: 120),
                    )
                  : overviewAsync.isLoading
                  ? ShimmerBox(
                      width: double.infinity,
                      height: 170.h,
                      borderRadius: 24.r,
                    )
                  : const SizedBox.shrink(),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20.w, 24.h, 20.w, 12.h),
              child: Row(
                children: [
                  Icon(
                    Icons.leaderboard_rounded,
                    size: 18.sp,
                    color: AppColors.emeraldInk,
                  ),
                  SizedBox(width: 8.w),
                  Text(
                    'Members',
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w700,
                      color: AppColors.inkText,
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 10.w,
                      vertical: 3.h,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.worshipAccentBg,
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Text(
                      '${g.memberCount}',
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w800,
                        color: AppColors.worshipAccent,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (overview != null) const PreviewBadge(),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: 20.w),
            sliver: SliverToBoxAdapter(
              child:
                  Container(
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(24.r),
                      border: Border.all(color: AppColors.borderWarm),
                    ),
                    child: Column(
                      children: [
                        for (var i = 0; i < members.length; i++) ...[
                          _tile(g, members[i], i + 1, overview, myId, isAdmin),
                          if (i != members.length - 1)
                            Divider(
                              height: 1,
                              indent: 60.w,
                              color: AppColors.borderWarm,
                            ),
                        ],
                        if (members.length == 1) ...[
                          Divider(height: 1, color: AppColors.borderWarm),
                          Padding(
                            padding: EdgeInsets.all(16.w),
                            child: Text(
                              'You’re the only one here so far. Share the invite '
                              'code above to bring others in.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12.sp,
                                height: 1.4,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ).slideIn(
                    RevealDirection.bottomEnd,
                    onVisible: true,
                    delay: const Duration(milliseconds: 80),
                  ),
            ),
          ),
          SliverToBoxAdapter(child: SizedBox(height: 110.h)),
        ],
      ),
    );
  }

  Widget _tile(
    GroupDetail group,
    GroupMember m,
    int rank,
    GroupSnapOverview? overview,
    String? myId,
    bool isAdmin,
  ) {
    final stats = overview?.members[m.userId];
    final isMe = m.userId == myId;
    // Admins can open anyone's details; other members only their own.
    final canOpen = isAdmin || isMe;
    return MemberSnapTile(
      member: m,
      stats: stats,
      rank: rank,
      isMe: isMe,
      canOpenDetails: canOpen,
      onOpenDetails: () async {
        final action = await showMemberDetailSheet(
          context,
          member: m,
          stats: stats,
          isMe: isMe,
          viewerIsAdmin: isAdmin,
        );
        if (action == MemberSheetAction.remove && mounted) {
          await _removeMember(group, m);
        }
      },
      onOpenSnap: () {
        final snap = stats?.latestSnap;
        if (snap != null) showSnapViewer(context, member: m, snap: snap);
      },
    );
  }
}
