import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../shared/widgets/islamic_ornaments.dart';
import '../../../../shared/widgets/pinned_hero_bar.dart';
import '../../domain/entities/group_streak.dart';
import '../providers/groups_providers.dart';
import '../widgets/streak_widgets.dart';

/// Pushed as a top-level route, so the bottom navigation bar is not shown.
class GroupStreakScreen extends ConsumerStatefulWidget {
  final String groupId;
  const GroupStreakScreen({super.key, required this.groupId});

  @override
  ConsumerState<GroupStreakScreen> createState() => _GroupStreakScreenState();
}

class _GroupStreakScreenState extends ConsumerState<GroupStreakScreen> {
  final _scroll = ScrollController();
  final _bar = ValueNotifier<double>(0);

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      final t = (_scroll.hasClients ? _scroll.offset / 140 : 0.0).clamp(
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

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(groupStreakProvider(widget.groupId));

    return Scaffold(
      backgroundColor: AppColors.parchment,
      floatingActionButton: async.hasValue
          ? FloatingActionButton.extended(
              onPressed: () {
                HapticFeedback.selectionClick();
                // TODO: open camera to log today's reading.
              },
              backgroundColor: AppColors.gold,
              foregroundColor: AppColors.heroSurface,
              icon: const Icon(Icons.camera_alt_rounded),
              label: Text(
                'Log today',
                style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w800),
              ),
            )
          : null,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Stack(
          children: [
            async.when(
              data: _content,
              loading: () => Center(
                child: CircularProgressIndicator(color: AppColors.gold),
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
                            ref.invalidate(groupStreakProvider(widget.groupId)),
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
                title: async.valueOrNull?.groupName ?? 'Group streak',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _content(GroupStreakSummary s) {
    return CustomScrollView(
      controller: _scroll,
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(child: _hero(s)),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 0),
          sliver: SliverToBoxAdapter(
            child: TodayProgressCard(summary: s).slideIn(
              RevealDirection.bottomStart,
              delay: const Duration(milliseconds: 260),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20.w, 26.h, 20.w, 12.h),
            child: Row(
              children: [
                Icon(
                  Icons.leaderboard_rounded,
                  size: 18.sp,
                  color: AppColors.gold,
                ).slideIn(
                  RevealDirection.bottomStart,
                  onVisible: true,
                  distance: 16,
                  duration: AppMotion.normal,
                ),
                SizedBox(width: 8.w),
                Text(
                  'Group activity',
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.inkText,
                  ),
                ).slideIn(
                  RevealDirection.start,
                  onVisible: true,
                  delay: const Duration(milliseconds: 50),
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: 20.w),
          sliver: SliverToBoxAdapter(
            child:
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(24.r),
                    border: Border.all(color: AppColors.borderWarm),
                  ),
                  child: Column(
                    children: [
                      for (var i = 0; i < s.members.length; i++) ...[
                        MemberTile(member: s.members[i], rank: i + 1),
                        if (i != s.members.length - 1)
                          Divider(
                            height: 1,
                            indent: 60.w,
                            color: AppColors.borderWarm,
                          ),
                      ],
                      Divider(height: 1, color: AppColors.borderWarm),
                      TextButton(
                        onPressed: () {},
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.toolsAccent,
                          minimumSize: Size.fromHeight(46.h),
                        ),
                        child: Text(
                          'View all ${s.memberCount} members',
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
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
    );
  }

  Widget _hero(GroupStreakSummary s) {
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.heroSurface, AppColors.emeraldInkDark],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(36.r)),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: GeometricPattern(
              color: AppColors.goldLight.withValues(alpha: 0.08),
              cell: 52,
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              20.w,
              MediaQuery.of(context).padding.top + 64.h,
              20.w,
              22.h,
            ),
            child: Column(
              children: [
                Text(
                  s.groupName.toUpperCase(),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.sp,
                    letterSpacing: 1.6,
                    fontWeight: FontWeight.w700,
                    color: AppColors.goldLight,
                  ),
                ).slideIn(RevealDirection.top, distance: 12),
                SizedBox(height: 14.h),
                SizedBox(
                  width: 96.w,
                  height: 96.w,
                  child: CustomPaint(
                    painter: StarPainter(
                      fill: AppColors.gold.withValues(alpha: 0.18),
                      stroke: AppColors.goldLight,
                      strokeWidth: 1.5,
                      inner: 0.76,
                    ),
                    child: Icon(
                      Icons.local_fire_department_rounded,
                      size: 44.sp,
                      color: AppColors.goldLight,
                    ),
                  ),
                ).slideIn(
                  RevealDirection.bottom,
                  delay: const Duration(milliseconds: 60),
                ),
                SizedBox(height: 10.h),
                AnimatedCount(
                  value: s.currentStreak,
                  fromZero: true,
                  style: TextStyle(
                    fontSize: 54.sp,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  'day streak together',
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: AppColors.onHeroSurface.withValues(alpha: 0.8),
                  ),
                ).slideIn(
                  RevealDirection.topEnd,
                  delay: const Duration(milliseconds: 140),
                ),
                SizedBox(height: 8.h),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 12.w,
                    vertical: 5.h,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(14.r),
                  ),
                  child: Text(
                    'Longest: ${s.longestStreak} days',
                    style: TextStyle(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w700,
                      color: AppColors.goldLight,
                    ),
                  ),
                ).slideIn(
                  RevealDirection.bottomStart,
                  delay: const Duration(milliseconds: 200),
                  duration: AppMotion.normal,
                ),
                SizedBox(height: 20.h),
                WeekStrip(week: s.week).slideIn(
                  RevealDirection.bottom,
                  delay: const Duration(milliseconds: 240),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
