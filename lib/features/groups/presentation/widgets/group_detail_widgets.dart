import '../../../prayer_logs/domain/current_prayer.dart';
import '../../../prayer_logs/domain/group_member_prayers.dart';
import '../../../prayer_logs/domain/prayer_log.dart';
import '../../../prayer_logs/presentation/prayer_labels.dart';
import '../../../prayer_logs/presentation/providers/prayer_logs_providers.dart';
import '../../domain/member_day_status.dart';
import 'group_card.dart' show shortAgo;
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  /// Opens the group's leaderboard screen.
  final VoidCallback onOpenLeaderboard;

  /// The group's streak board, for today's progress in the header. Null while
  /// loading or if it failed.
  final GroupStreakBoard? board;

  const GroupDetailHero({
    super.key,
    required this.group,
    required this.myRole,
    required this.onInvite,
    required this.onOpenStats,
    required this.onOpenLeaderboard,
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
                    if (board == null || board!.isEmpty) ...[
                      chip(
                        Icons.insights_rounded,
                        'Statistics',
                        onTap: onOpenStats,
                      ),
                      chip(
                        Icons.leaderboard_rounded,
                        'Leaderboard',
                        onTap: onOpenLeaderboard,
                      ),
                    ],
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
                    onOpenLeaderboard: onOpenLeaderboard,
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
  final VoidCallback onOpenLeaderboard;
  const _HeroTodaySummary({
    required this.board,
    required this.onOpenStats,
    required this.onOpenLeaderboard,
  });

  Widget _heroLink(IconData icon, String text, VoidCallback onTap) =>
      TextButton.icon(
        onPressed: onTap,
        style: TextButton.styleFrom(
          foregroundColor: AppColors.goldLight,
          padding: EdgeInsets.symmetric(horizontal: 0, vertical: 2.h),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        icon: Icon(icon, size: 16.sp),
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text,
              style: TextStyle(fontSize: 12.5.sp, fontWeight: FontWeight.w700),
            ),
            SizedBox(width: 2.w),
            Icon(Icons.chevron_right_rounded, size: 16.sp),
          ],
        ),
      );

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
          // Everything beyond today's snapshot lives on these two screens.
          Wrap(
            spacing: 18.w,
            children: [
              _heroLink(Icons.insights_rounded, 'View statistics', onOpenStats),
              _heroLink(
                Icons.leaderboard_rounded,
                'Leaderboard',
                onOpenLeaderboard,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A member's row in the Members list: the picture, the name (with an Admin
/// badge), one line saying where they are today, and the five prayers as small
/// bars. On the right, their streak.
///
/// The status line is, in this order:
/// - **blocked**: a "Blocked" tag (their snaps are hidden from the viewer);
/// - **waiting**: while a prayer's time is open and they have not logged it,
///   that prayer and the time left until the next one starts, with an
///   hourglass (the viewer's own row shows the time without the hourglass);
/// - **a snap**: a new one to open, one already opened, or one that expired;
/// - **a log without a snap**: what they prayed last;
/// - nothing yet today, or, before today's feed has loaded, when they joined.
///
/// Tapping the row opens the member's profile (where report and block are).
/// Tapping a new snap opens it.
class MemberSnapTile extends ConsumerStatefulWidget {
  final GroupMember member;
  final bool isMe;

  /// Tapping the row opens the member's details, for every member.
  final VoidCallback onOpenDetails;

  /// Opens the member's latest snap. Only offered while it is unopened.
  final VoidCallback onOpenSnap;

  /// Their latest snap as this viewer sees it (never active on the viewer's
  /// own row).
  final SnapState snapState;

  /// Their streak (current streak, today's goal), from the board.
  final MemberStreak? streak;

  /// What they logged today, from the group feed. Null until it has loaded.
  final GroupMemberPrayers? prayers;

  /// The viewer has blocked this member: their snaps are hidden.
  final bool isBlocked;

  const MemberSnapTile({
    super.key,
    required this.member,
    required this.isMe,
    required this.onOpenDetails,
    required this.onOpenSnap,
    this.snapState = SnapState.none,
    this.streak,
    this.prayers,
    this.isBlocked = false,
  });

  @override
  ConsumerState<MemberSnapTile> createState() => _MemberSnapTileState();
}

class _MemberSnapTileState extends ConsumerState<MemberSnapTile> {
  /// Ticks while this member's countdown is running, so "1h 14m left" stays
  /// right. Not running for anyone else: most rows have nothing to count.
  Timer? _timer;

  /// The server's clock minus the phone's, from when the open-prayer answer
  /// arrived, so the countdown follows the server even if the phone is off.
  Duration _skew = Duration.zero;
  CurrentPrayerState? _seen;

  /// The answer a refresh was last asked for, shared by every row so a window
  /// that closes is refreshed once, not once per member.
  static CurrentPrayerState? _refreshedFor;

  MemberSnapTile get w => widget;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _tick() {
    if (!mounted) return;
    final s = _seen;
    final boundary = s?.current?.endsAt ?? s?.next?.startsAt;
    if (s != null &&
        boundary != null &&
        !DateTime.now().add(_skew).isBefore(boundary) &&
        !identical(_refreshedFor, s)) {
      _refreshedFor = s;
      ref.read(currentPrayerProvider.notifier).refresh();
    }
    setState(() {});
  }

  void _ensureTimer(bool needed) {
    if (needed) {
      _timer ??= Timer.periodic(const Duration(seconds: 15), (_) => _tick());
    } else if (_timer != null) {
      _timer!.cancel();
      _timer = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final window = ref.watch(currentPrayerProvider).valueOrNull;
    if (!identical(window, _seen)) {
      _seen = window;
      _skew = window == null
          ? Duration.zero
          : window.now.difference(DateTime.now());
    }
    final now = DateTime.now().add(_skew);
    final day = memberDayStatus(prayers: w.prayers, window: window, now: now);
    _ensureTimer(day.waitingFor != null);
    final streakLine = w.streak;

    return InkWell(
      onTap: w.onOpenDetails,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 14.h),
        child: Row(
          children: [
            MemberAvatar(
              member: w.member,
              size: 54.w,
              ring: streakLine?.todayQualified ?? false,
            ),
            SizedBox(width: 14.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          w.isMe
                              ? '${w.member.displayName} (You)'
                              : w.member.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w800,
                            color: AppColors.inkText,
                          ),
                        ),
                      ),
                      if (w.member.role == GroupRole.admin) ...[
                        SizedBox(width: 3.w),
                        const RoleBadge(role: GroupRole.admin, soft: true),
                      ],
                    ],
                  ),
                  SizedBox(height: 4.h),
                  _statusLine(day, now),
                  if (day.days.isNotEmpty) ...[
                    SizedBox(height: 7.h),
                    _DayBars(days: day.days),
                  ],
                ],
              ),
            ),
            if (streakLine != null) ...[
              SizedBox(width: 8.w),
              Semantics(
                label: '${streakLine.currentStreak} day streak',
                excludeSemantics: true,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('🔥', style: TextStyle(fontSize: 16.sp)),
                    SizedBox(width: 2.w),
                    Text(
                      '${streakLine.currentStreak}',
                      style: TextStyle(
                        fontSize: 20.sp,
                        fontWeight: FontWeight.w800,
                        color: AppColors.emeraldInk,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            SizedBox(width: 4.w),
          ],
        ),
      ),
    );
  }

  /// The one line under the name. See the class comment for the order.
  Widget _statusLine(MemberDayStatus day, DateTime now) {
    final muted = TextStyle(fontSize: 14.sp, color: AppColors.textSecondary);

    if (w.isBlocked) return const _BlockedTag();

    final waiting = day.waitingFor;
    if (waiting != null && day.left != null) {
      return _MemberStatusText(
        semantics:
            '${waiting.label}: ${countdown(day.left!)} left to log'
            '${w.isMe ? '' : ', not logged yet'}',
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                '${waiting.label} · ${countdown(day.left!)} left',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: muted,
              ),
            ),
            // Marks who has not sent theirs yet; the viewer knows their own.
            if (!w.isMe) ...[
              SizedBox(width: 5.w),
              Icon(
                Icons.hourglass_bottom_rounded,
                size: 15.sp,
                color: AppColors.amber,
              ),
            ],
          ],
        ),
      );
    }

    final snapLog = w.prayers?.latestSnapLog(now);
    if (snapLog != null && w.snapState != SnapState.none) {
      final what =
          '${snapLog.prayer.label} · ${shortAgo(now.difference(snapLog.loggedAt))}';
      return MemberSnapStatus(
        state: w.snapState,
        text: what,
        onTap: w.onOpenSnap,
      );
    }

    final logs = w.prayers?.logs ?? const <PrayerLog>[];
    if (logs.isNotEmpty) {
      var last = logs.first;
      for (final l in logs) {
        if (l.loggedAt.isAfter(last.loggedAt)) last = l;
      }
      return Text(
        'Prayed ${last.prayer.label} · ${shortAgo(now.difference(last.loggedAt))}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: muted,
      );
    }
    if (w.prayers != null) {
      return Text('No w.prayers yet today', style: muted);
    }
    return Text(joinedLabel(w.member.joinedAt), style: muted);
  }
}

/// A status line with one accessible label.
class _MemberStatusText extends StatelessWidget {
  final String semantics;
  final Widget child;
  const _MemberStatusText({required this.semantics, required this.child});

  @override
  Widget build(BuildContext context) =>
      Semantics(label: semantics, excludeSemantics: true, child: child);
}

/// A member's latest snap on their row: "New snap · Asr · 2m" (filled square,
/// bold, tap to open), "Viewed · Asr · 22m" (outlined square), or "Expired".
/// Only [SnapState.unopened] is tappable.
class MemberSnapStatus extends StatelessWidget {
  final SnapState state;

  /// "Asr · 2m".
  final String text;
  final VoidCallback? onTap;

  const MemberSnapStatus({
    super.key,
    required this.state,
    required this.text,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = state == SnapState.unopened && onTap != null;
    final (label, semantics) = switch (state) {
      SnapState.unopened => ('New snap', 'View snap'),
      SnapState.opened => ('Viewed', 'Snap already opened'),
      SnapState.expired => ('Expired', 'Snap expired'),
      SnapState.none => ('', 'No snap'),
    };
    final box = 15.w;
    final Widget icon = switch (state) {
      SnapState.unopened => Container(
        width: box,
        height: box,
        decoration: BoxDecoration(
          color: AppColors.emeraldInk,
          borderRadius: BorderRadius.circular(4.r),
        ),
      ),
      _ => Container(
        width: box,
        height: box,
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.textMuted, width: 1.6),
          borderRadius: BorderRadius.circular(4.r),
        ),
      ),
    };
    final style = TextStyle(
      fontSize: 12.sp,
      fontWeight: enabled ? FontWeight.w800 : FontWeight.w500,
      color: enabled ? AppColors.amberDeep : AppColors.textSecondary,
    );

    return Semantics(
      button: enabled,
      enabled: enabled,
      label: semantics,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? onTap : null,
        child: Opacity(
          opacity: state == SnapState.expired ? 0.5 : 1,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              icon,
              SizedBox(width: 4.w),
              Flexible(
                child: Text(
                  '$label · $text',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: style,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The five prayers as short bars: green logged, red missed, grey still to
/// come (or open and not logged yet).
class _DayBars extends StatelessWidget {
  final List<DayPrayer> days;
  const _DayBars({required this.days});

  @override
  Widget build(BuildContext context) {
    const names = ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];
    final spoken = [
      for (final (i, d) in days.indexed)
        '${names[i]} ${switch (d) {
          DayPrayer.logged => 'logged',
          DayPrayer.missed => 'missed',
          DayPrayer.pending => 'not yet',
        }}',
    ].join(', ');
    return Semantics(
      label: 'Today: $spoken',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (i, d) in days.indexed) ...[
            if (i > 0) SizedBox(width: 6.w),
            Container(
              width: 24.w,
              height: 5.h,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3.r),
                color: switch (d) {
                  DayPrayer.logged => Colors.green,
                  DayPrayer.missed => AppColors.error,
                  DayPrayer.pending => AppColors.borderWarm,
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// "Blocked", on a member's row.
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
