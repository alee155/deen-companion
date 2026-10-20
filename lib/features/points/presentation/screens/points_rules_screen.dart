import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/motion/motion.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../shared/widgets/failure_view.dart';
import '../../../../shared/widgets/feature_hero.dart';
import '../../../../shared/widgets/pinned_hero_bar.dart';
import '../../../../shared/widgets/shimmer_box.dart';
import '../../domain/entities/points_rule.dart';
import '../providers/points_providers.dart';
import '../../../auth/presentation/providers/auth_session_provider.dart';
import '../../../groups/presentation/providers/groups_providers.dart';
import '../../../streaks/presentation/widgets/daily_goal_section.dart';
import '../widgets/points_chart.dart';

/// How many points each prayer earns. Open to every member of a group, admin
/// or not; the numbers come from `GET /points/rules`.
class PointsRulesScreen extends ConsumerStatefulWidget {
  /// The group these rules are being read for. With it, the screen also shows
  /// that group's daily goal (and lets its admin change it).
  final String? groupId;

  const PointsRulesScreen({super.key, this.groupId});

  @override
  ConsumerState<PointsRulesScreen> createState() => _PointsRulesScreenState();
}

class _PointsRulesScreenState extends ConsumerState<PointsRulesScreen> {
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
    final rules = ref.watch(pointsRulesProvider);
    final table = rules.valueOrNull;

    return Scaffold(
      backgroundColor: AppColors.parchment,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Stack(
          children: [
            RefreshIndicator(
              edgeOffset: 90.h,
              onRefresh: () => ref.read(pointsRulesProvider.notifier).refresh(),
              child: CustomScrollView(
                controller: _scroll,
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                slivers: [
                  SliverToBoxAdapter(child: _hero(table)),
                  ...rules.when(
                    data: (t) => _loaded(t),
                    loading: _loading,
                    error: (error, _) => _failed(error),
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
                title: 'Rules',
                shadow: false,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _hero(PointsRules? table) {
    final known = table != null && !table.isEmpty;
    return FeatureHero(
      title: 'Rules',
      subtitle: 'Every prayer you log while its time is open earns points.',
      ghostIcon: Icons.emoji_events_rounded,
      compact: true,
      chips: [
        if (known) ...[
          FeatureHeroChip(Icons.star_rounded, 'Best: ${table.highest} points'),
          FeatureHeroChip(
            Icons.event_available_rounded,
            'Full day: ${table.total} points',
          ),
        ],
      ],
    );
  }

  /// Whether the signed-in user is this group's admin (false until the group
  /// has loaded).
  bool _isAdmin(String groupId) {
    final myId = ref.watch(authSessionProvider).userId;
    return ref.watch(groupDetailProvider(groupId)).valueOrNull?.isAdmin(myId) ??
        false;
  }

  List<Widget> _loaded(PointsRules table) {
    if (table.isEmpty) {
      return [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(20.w, 28.h, 20.w, 0),
          sliver: SliverToBoxAdapter(
            child: Container(
              padding: EdgeInsets.all(24.w),
              decoration: _cardDecoration(),
              child: Column(
                children: [
                  Icon(
                    Icons.emoji_events_outlined,
                    size: 34.sp,
                    color: AppColors.textMuted,
                  ),
                  SizedBox(height: 10.h),
                  Text(
                    'No rules have been set yet.',
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ];
    }
    return [
      SliverToBoxAdapter(child: _sectionHeader('Points per prayer')),
      SliverPadding(
        padding: EdgeInsets.symmetric(horizontal: 20.w),
        sliver: SliverToBoxAdapter(
          child: PointsChart(
            table: table,
          ).slideIn(RevealDirection.bottom, distance: 18),
        ),
      ),
      if (widget.groupId case final groupId?) ...[
        SliverToBoxAdapter(child: _sectionHeader('Daily goal')),
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: 20.w),
          sliver: SliverToBoxAdapter(
            child: DailyGoalSection(
              groupId: groupId,
              isAdmin: _isAdmin(groupId),
            ),
          ),
        ),
      ],
      SliverPadding(
        padding: EdgeInsets.fromLTRB(20.w, 18.h, 20.w, 0),
        sliver: const SliverToBoxAdapter(child: _HowItWorks()),
      ),
    ];
  }

  List<Widget> _loading() => [
    SliverToBoxAdapter(child: _sectionHeader('Points per prayer')),
    SliverPadding(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      sliver: SliverToBoxAdapter(
        child: ShimmerBox(
          width: double.infinity,
          height: 300.h,
          borderRadius: 28.r,
        ),
      ),
    ),
  ];

  List<Widget> _failed(Object error) => [
    SliverPadding(
      padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 0),
      sliver: SliverToBoxAdapter(
        child: FailureView(
          failure: failureFrom(error),
          onRetry: () => ref.read(pointsRulesProvider.notifier).refresh(),
        ),
      ),
    ),
  ];

  Widget _sectionHeader(String title) => Padding(
    padding: EdgeInsets.fromLTRB(24.w, 24.h, 24.w, 12.h),
    child: Text(
      title,
      style: TextStyle(
        fontSize: 18.sp,
        fontWeight: FontWeight.w700,
        color: AppColors.inkText,
      ),
    ).slideIn(RevealDirection.bottomStart, onVisible: true),
  );
}

BoxDecoration _cardDecoration({Color? border, double borderWidth = 1}) =>
    BoxDecoration(
      color: AppColors.surfaceLight,
      borderRadius: BorderRadius.circular(22.r),
      border: Border.all(
        color: border ?? AppColors.borderWarm,
        width: borderWidth,
      ),
    );

/// What a member needs to know to earn the points above.
class _HowItWorks extends StatelessWidget {
  const _HowItWorks();

  @override
  Widget build(BuildContext context) {
    Widget step(IconData icon, String text) => Padding(
      padding: EdgeInsets.only(top: 10.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28.w,
            height: 28.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.worshipAccentBg,
            ),
            child: Icon(icon, size: 15.sp, color: AppColors.emeraldInk),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: 4.h),
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 13.sp,
                  height: 1.4,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );

    return Container(
      padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 16.h),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.lightbulb_outline_rounded,
                size: 18.sp,
                color: AppColors.amberDeep,
              ),
              SizedBox(width: 8.w),
              Text(
                'How it works',
                style: TextStyle(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w800,
                  color: AppColors.inkText,
                ),
              ),
            ],
          ),
          step(
            Icons.camera_alt_rounded,
            'Log a prayer with a photo while its time is open.',
          ),
          step(
            Icons.check_circle_outline_rounded,
            'Each prayer can be logged once a day.',
          ),
          step(
            Icons.leaderboard_rounded,
            'Your points count toward your group’s leaderboard.',
          ),
        ],
      ),
    ).slideIn(RevealDirection.bottom, onVisible: true);
  }
}
