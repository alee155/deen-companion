import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/motion/motion.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../shared/widgets/feature_hero.dart';
import '../../../../shared/widgets/pinned_hero_bar.dart';
import '../../../auth/presentation/providers/auth_session_provider.dart';
import '../../../groups/presentation/providers/groups_providers.dart';
import '../../domain/bars_model.dart';
import '../providers/chart_providers.dart';
import '../providers/statistics_providers.dart';
import '../widgets/stats_chart_panel.dart';
import '../widgets/stats_members_section.dart';

/// A group's statistics: one chart of how the days are going (the group, you,
/// or any member you tap in the list), and the members underneath. Built from
/// the same pieces as the Rules screen: the dark hero, the dark chart panel,
/// and the members card from the group screen.
class GroupStatisticsScreen extends ConsumerStatefulWidget {
  final String groupId;
  const GroupStatisticsScreen({super.key, required this.groupId});

  @override
  ConsumerState<GroupStatisticsScreen> createState() =>
      _GroupStatisticsScreenState();
}

class _GroupStatisticsScreenState extends ConsumerState<GroupStatisticsScreen> {
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

  /// After a member is chosen the chart is what changed, so show it.
  void _showChart() {
    if (!_scroll.hasClients) return;
    _scroll.animateTo(
      0,
      duration: context.motion.duration(AppMotion.slow),
      curve: AppMotion.entrance,
    );
  }

  Future<void> _refresh() async {
    ref.read(refreshStatisticsProvider)();
    try {
      await ref.read(groupOverviewProvider(widget.groupId).future);
    } catch (_) {}
  }

  Widget _sectionHeader(String title, {String? hint}) => Padding(
    padding: EdgeInsets.fromLTRB(24.w, 24.h, 24.w, 12.h),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.w700,
            color: AppColors.inkText,
          ),
        ),
        if (hint != null) ...[
          SizedBox(height: 2.h),
          Text(
            hint,
            style: TextStyle(fontSize: 12.sp, color: AppColors.textSecondary),
          ),
        ],
      ],
    ),
  );

  /// The few numbers worth seeing before anything else, as chips in the hero.
  List<FeatureHeroChip> _chips() {
    final overview = ref
        .watch(groupOverviewProvider(widget.groupId))
        .valueOrNull;
    final summary = ref.watch(mySummaryProvider).valueOrNull;
    return [
      if (overview != null) ...[
        FeatureHeroChip(
          Icons.today_rounded,
          '${overview.totals.membersActiveToday} of ${overview.memberCount} on track today',
        ),
        if (overview.averageParticipationPercent != null)
          FeatureHeroChip(
            Icons.groups_rounded,
            '${overview.averageParticipationPercent!.round()}% average',
          ),
      ],
      if (summary?.completion.percent != null)
        FeatureHeroChip(
          Icons.person_rounded,
          'You ${summary!.completion.percent!.round()}% complete',
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final myId = ref.watch(authSessionProvider).userId;
    final group = ref.watch(groupDetailProvider(widget.groupId)).valueOrNull;
    final isAdmin = group?.isAdmin(myId) ?? false;
    final subject = ref.watch(statsSubjectProvider);
    final memberName = subject is MemberSubject
        ? ref
              .watch(groupMemberStatsProvider(widget.groupId))
              .valueOrNull
              ?.where((m) => m.userId == subject.userId)
              .map((m) => m.displayName)
              .firstOrNull
        : null;

    return Scaffold(
      backgroundColor: AppColors.parchment,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Stack(
          children: [
            RefreshIndicator(
              edgeOffset: 90.h,
              onRefresh: _refresh,
              child: CustomScrollView(
                controller: _scroll,
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                slivers: [
                  SliverToBoxAdapter(
                    child: FeatureHero(
                      title: 'Statistics',
                      subtitle: group?.name ?? 'How the group is doing',
                      ghostIcon: Icons.insights_rounded,
                      compact: true,
                      chips: _chips(),
                    ),
                  ),
                  SliverToBoxAdapter(child: _sectionHeader('Daily activity')),
                  SliverPadding(
                    padding: EdgeInsets.symmetric(horizontal: 20.w),
                    sliver: SliverToBoxAdapter(
                      child: StatsChartPanel(
                        groupId: widget.groupId,
                        memberName: memberName,
                      ).slideIn(RevealDirection.bottom, distance: 18),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: _sectionHeader(
                      'Members',
                      hint: 'Tap a member to see their days on the chart.',
                    ),
                  ),
                  SliverPadding(
                    padding: EdgeInsets.symmetric(horizontal: 20.w),
                    sliver: SliverToBoxAdapter(
                      child: StatsMembersSection(
                        groupId: widget.groupId,
                        myId: myId,
                        isAdmin: isAdmin,
                        onChosen: _showChart,
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: MediaQuery.of(context).padding.bottom + 32.h,
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: PinnedHeroBar(
                opacity: _bar,
                title: 'Statistics',
                shadow: false,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
