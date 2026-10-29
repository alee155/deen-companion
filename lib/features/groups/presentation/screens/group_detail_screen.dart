import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/motion/motion.dart';
import '../../../../core/utils/flow_log.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../shared/widgets/pinned_hero_bar.dart';
import '../../../auth/presentation/providers/auth_session_provider.dart';
import '../../../prayer_logs/presentation/providers/prayer_logs_providers.dart';
import '../../../prayer_logs/domain/group_member_prayers.dart';
import '../../../prayer_logs/domain/prayer_log.dart';
import '../../../prayer_logs/presentation/snap_viewing.dart';
import '../../../prayer_logs/presentation/widgets/snap_photo_viewer.dart';
import '../../../prayer_logs/presentation/prayer_labels.dart';
import '../../../prayer_logs/presentation/widgets/prayer_dots_row.dart';
import '../../domain/entities/group_detail.dart';
import '../../../group_live/presentation/providers/group_live_store.dart';
import '../../../group_live/presentation/widgets/live_status_chip.dart';
import '../../../streaks/domain/entities/group_streaks.dart';
import '../providers/groups_providers.dart';
import '../widgets/delete_group_sheet.dart';
import '../widgets/edit_group_sheet.dart';
import '../widgets/group_detail_skeleton.dart';
import '../widgets/group_detail_widgets.dart';
import '../widgets/invite_group_sheet.dart';
import '../widgets/leave_group_sheet.dart';
import '../widgets/manage_group_sheet.dart';
import '../widgets/remove_member_sheet.dart';
import '../../../snaps/presentation/add_groups_entry.dart';
import '../../../snaps/presentation/providers/snap_providers.dart';
import '../../../snaps/presentation/snap_entry.dart';
import '../widgets/send_snap_button.dart';
import '../../../moderation/domain/entities/report_target.dart';
import '../../../moderation/presentation/moderation_flows.dart';
import '../../../moderation/presentation/providers/moderation_providers.dart';
import '../widgets/member_detail_sheet.dart';
import '../widgets/snap_widgets.dart';

/// Pushed as a top-level route, so the bottom navigation bar is not shown.
///
/// Everything here is real: the group and members from the groups API, each
/// member's streak and today's goal from the streak board, and today's prayers,
/// points and photos from the group feed.
class GroupDetailScreen extends ConsumerStatefulWidget {
  final String groupId;
  const GroupDetailScreen({super.key, required this.groupId});

  @override
  ConsumerState<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends ConsumerState<GroupDetailScreen>
    with WidgetsBindingObserver {
  /// Two quiet refreshes are never closer than this (unless forced), so a poll
  /// that lands just after the app returns to the foreground does not fetch
  /// twice.
  static const minGap = Duration(seconds: 20);

  final _scroll = ScrollController();
  final _bar = ValueNotifier<double>(0);

  /// Running for [minGap] after each quiet refresh; while it runs, further
  /// non-forced refreshes are skipped.
  Timer? _cooldown;

  GroupFeedKey get _feedKey => (groupId: widget.groupId, date: null);

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

    WidgetsBinding.instance.addObserver(this);

    // Whether a snap can be sent right now is the server's call; ask again so
    // the button never shows for a prayer that is already logged.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(currentPrayerProvider.notifier).refresh();
    });

    // Reopened with the group still held from an earlier visit: it is shown
    // at once, and brought up to date behind the scenes (no skeleton).
    final detail = groupDetailProvider(widget.groupId);
    if (ref.exists(detail) && ref.read(detail).hasValue) {
      FlowLog.log(
        'GROUP',
        'REOPENED WITH KEPT DATA -> SHOWING IT NOW, refreshing quietly',
      );
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _refreshQuietly(detail: true, force: true),
      );
    }
  }

  /// Fetches again without touching what is on screen: the old data stays
  /// until the new arrives, and a failure is ignored (the old data is still
  /// right as far as we know). [detail] also reloads the member list.
  void _refreshQuietly({required bool detail, bool force = false}) {
    if (!mounted) return;
    if (!force && (_cooldown?.isActive ?? false)) return;

    final current = ref.read(groupDetailProvider(widget.groupId));
    // Still on the very first load: it is already fetching.
    if (current.isLoading && !current.hasValue) return;

    _cooldown?.cancel();
    _cooldown = Timer(minGap, () {});
    FlowLog.log(
      'GROUP',
      'QUIET REFRESH (${detail ? 'group and prayers' : 'prayers'}) - '
          'the current data stays on screen',
    );
    ref.invalidate(groupPrayersProvider(_feedKey));
    // Numbers and members come from the summary (a 304 when nothing moved).
    unawaited(ref.read(groupLiveProvider(widget.groupId).notifier).refresh());
    if (detail) ref.invalidate(groupDetailProvider(widget.groupId));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    FlowLog.log('GROUP', 'APP RETURNED TO THE FOREGROUND');
    ref.read(currentPrayerProvider.notifier).refresh();
    _refreshQuietly(detail: true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cooldown?.cancel();
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
      case ManageAction.rules:
        await context.push(
          '/points-rules?groupId=${Uri.encodeQueryComponent(group.id)}',
        );
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
    // Deleted by the admin, or this user was removed: leave the screen.
    ref.listen(groupLiveProvider(widget.groupId).select((s) => s.gone), (
      _,
      gone,
    ) {
      if (gone == null || !mounted) return;
      _toast(
        gone == GroupGone.deleted
            ? 'This group was deleted'
            : 'You’re no longer a member of this group',
      );
      Navigator.of(context).maybePop();
    });
    final async = ref.watch(groupDetailProvider(widget.groupId));
    final myId = ref.watch(authSessionProvider).userId;
    final group = async.valueOrNull;
    final isAdmin = group?.isAdmin(myId) ?? false;
    // The camera button is always there. A snap logs the prayer that is open
    // now, once, so when that isn't possible the button turns grey and a tap
    // says why (rather than failing after the photo, timer and groups were
    // all chosen).
    final snapAvailability = ref.watch(snapAvailabilityProvider);

    return Scaffold(
      backgroundColor: AppColors.parchment,
      floatingActionButton: group == null
          ? null
          : SendSnapButton(
              available: snapAvailability.isAvailable,
              onPressed: () => openSnapFlow(context, ref, groupId: group.id),
            ),
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Stack(
          children: [
            // The skeleton fades into the content (or the error) rather than
            // popping, so the screen settles instead of jumping. A retry after
            // an error shows the skeleton again while it reloads.
            ContentSwitcher(
              child: KeyedSubtree(
                key: ValueKey(
                  async.hasValue
                      ? 'content'
                      : async.isLoading
                      ? 'loading'
                      : 'error',
                ),
                child: async.hasValue
                    ? _content(async.requireValue, myId, isAdmin)
                    : async.isLoading
                    ? const GroupDetailSkeleton()
                    : _error(async.error!),
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

  Widget _error(Object error) => Center(
    child: Padding(
      padding: EdgeInsets.all(32.w),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(error.toString(), textAlign: TextAlign.center),
          SizedBox(height: 12.h),
          FilledButton(
            onPressed: () =>
                ref.invalidate(groupDetailProvider(widget.groupId)),
            child: const Text('Try again'),
          ),
        ],
      ),
    ),
  );

  Widget _content(GroupDetail g, String? myId, bool isAdmin) {
    final board = ref.watch(liveGroupBoardProvider(g.id));

    // Today's prayers per member, for the circles on each card. Absent while
    // loading or if it failed (e.g. offline): the cards then show no circles
    // rather than a row of "not logged".
    final feed = ref.watch(liveGroupFeedProvider(g.id));
    final prayersByMember = {
      for (final m in feed ?? const <GroupMemberPrayers>[]) m.userId: m,
    };

    // Most recent snap first. Members with no snap follow, in the streak
    // board's order (longest current streak first; anyone it does not list
    // goes last).
    final place = board == null
        ? const <String, int>{}
        : {for (final (i, e) in board.entries.indexed) e.userId: i};
    final fallback = board?.entries.length ?? 0;
    final now = DateTime.now();
    DateTime? lastSnap(GroupMember m) =>
        prayersByMember[m.userId]?.latestSnapLog(now)?.loggedAt;
    final members = [...g.members];
    final original = {for (final (i, m) in members.indexed) m.userId: i};
    members.sort((a, b) {
      final sa = lastSnap(a);
      final sb = lastSnap(b);
      if (sa != null || sb != null) {
        if (sa == null) return 1;
        if (sb == null) return -1;
        final byTime = sb.compareTo(sa);
        if (byTime != 0) return byTime;
      }
      final byStreak = (place[a.userId] ?? fallback).compareTo(
        place[b.userId] ?? fallback,
      );
      return byStreak != 0
          ? byStreak
          : original[a.userId]!.compareTo(original[b.userId]!);
    });

    return RefreshIndicator(
      edgeOffset: 90.h,
      onRefresh: () async {
        _cooldown?.cancel();
        _cooldown = Timer(minGap, () {});
        ref.invalidate(groupDetailProvider(g.id));
        ref.invalidate(groupPrayersProvider);
        await Future.wait([
          ref.read(groupDetailProvider(g.id).future),
          ref.read(groupLiveProvider(g.id).notifier).refresh(),
        ]);
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
              board: board,
              onInvite: () =>
                  showInviteGroupSheet(context, group: g, isAdmin: isAdmin),
              onOpenStats: () =>
                  context.push('/groups/${Uri.encodeComponent(g.id)}/stats'),
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
                  const LiveStatusChip(),
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
                          _tile(
                            g,
                            members[i],
                            i + 1,
                            board,
                            myId,
                            isAdmin,
                            prayersByMember[members[i].userId],
                          ),
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
    GroupStreakBoard? board,
    String? myId,
    bool isAdmin,
    GroupMemberPrayers? prayers,
  ) {
    // Each figure shows once its own source has loaded: the streak from the
    // board, today's prayers and points from the group feed.
    final streak = board?.of(m.userId);
    final isMe = m.userId == myId;
    // Admins can open anyone's details; other members only their own.
    final canOpen = isAdmin || isMe;
    // A blocked member's snaps are hidden from the viewer.
    final isBlocked = ref.watch(blockedUserIdsProvider).contains(m.userId);
    // Snaps are for the other members: the sender does not open their own.
    final snapState = isMe || isBlocked
        ? SnapState.none
        : prayers?.latestSnapLog(DateTime.now())?.snapState(DateTime.now()) ??
              SnapState.none;
    final safetyUser = SafetyUser(
      id: m.userId,
      name: m.displayName,
      avatarUrl: m.avatarUrl,
    );
    return MemberSnapTile(
      member: m,
      snapState: snapState,
      isBlocked: isBlocked,
      // Everyone can report or block another member, whatever their role.
      // Your own row: add the snap you already sent to more groups.
      onAddGroups: isMe && ref.watch(addableSnapLogProvider) != null
          ? () => openAddGroups(context, log: ref.read(addableSnapLogProvider)!)
          : null,
      onMore: isMe
          ? null
          : () => showUserSafetyActions(context, ref, user: safetyUser),
      streak: streak,
      prayersToday: prayers?.loggedCount,
      pointsToday: prayers?.totalPoints,
      rank: rank,
      isMe: isMe,
      canOpenDetails: canOpen,
      onOpenDetails: () async {
        final action = await showMemberDetailSheet(
          context,
          member: m,
          streak: streak,
          pointsToday: prayers?.totalPoints,
          isMe: isMe,
          viewerIsAdmin: isAdmin,
          // Today's prayer circles live here, not on the card.
          prayerRow: prayers == null
              ? null
              : PrayerDotsRow(
                  member: prayers,
                  viewable: !isMe && !isBlocked,
                  showLabels: true,
                  size: 36,
                  onSnapAction: isMe
                      ? null
                      : (log, action) => _onSnapAction(m, log.id, action),
                ),
        );
        if (action == MemberSheetAction.remove && mounted) {
          await _removeMember(group, m);
        }
      },
      onOpenSnap: () => _openMemberPhoto(group, m),
    );
  }

  /// Opens the member's latest photo. The feed is read again first: photo
  /// links are signed and regenerated on every read, so a screen left open for
  /// a while would otherwise try an expired one.
  Future<void> _openMemberPhoto(GroupDetail group, GroupMember m) async {
    final key = (groupId: group.id, date: null as String?);
    FlowLog.log(
      'GROUP FEED',
      'USER TAPPED ${m.displayName}\'S PHOTO -> getting a fresh link',
    );
    List<GroupMemberPrayers> feed;
    try {
      feed = await ref.refresh(groupPrayersProvider(key).future);
    } catch (_) {
      // Offline or the call failed: the link we already have may still work.
      feed = ref.read(groupPrayersProvider(key)).valueOrNull ?? const [];
    }
    if (!mounted) return;

    GroupMemberPrayers? theirs;
    for (final f in feed) {
      if (f.userId == m.userId) theirs = f;
    }
    final log = theirs?.latestSnapLog(DateTime.now());
    if (ref.read(blockedUserIdsProvider).contains(m.userId)) {
      _toast(
        'You’ve blocked ${m.displayName}. Unblock them to see their snaps.',
      );
      return;
    }
    if (log == null) {
      FlowLog.log('GROUP FEED', 'NO PHOTO AVAILABLE for ${m.displayName}');
      _toast('No snap to show right now');
      return;
    }
    FlowLog.log(
      'GROUP FEED',
      'OPENING ${m.displayName}\'S ${log.prayer.name.toUpperCase()} SNAP',
    );
    final action = await openMemberSnap(
      context,
      ref,
      log: log,
      title: m.displayName,
      subtitle: '${log.prayer.label} · ${timeAgo(log.loggedAt)}',
      avatar: MemberAvatar(member: m, size: 38.w),
    );
    if (action != null && mounted) _onSnapAction(m, log.id, action);
  }

  /// The viewer's ⋯ menu: report this snap, or block the person.
  void _onSnapAction(GroupMember m, String logId, SnapViewerAction action) {
    final user = SafetyUser(
      id: m.userId,
      name: m.displayName,
      avatarUrl: m.avatarUrl,
    );
    switch (action) {
      case SnapViewerAction.report:
        startReport(
          context,
          ref,
          ReportSnapTarget(
            snapId: logId,
            userId: m.userId,
            userName: m.displayName,
          ),
          avatarUrl: m.avatarUrl,
        );
      case SnapViewerAction.block:
        startBlock(context, ref, user);
    }
  }
}
