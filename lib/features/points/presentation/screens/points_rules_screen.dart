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
import '../../../prayer_logs/presentation/prayer_labels.dart';
import '../../../prayer_times/domain/entities/prayer_times.dart';
import '../../domain/entities/points_rule.dart';
import '../providers/points_providers.dart';

/// How many points each prayer earns. Open to every member of a group, admin
/// or not; the numbers come from `GET /points/rules`.
class PointsRulesScreen extends ConsumerStatefulWidget {
  const PointsRulesScreen({super.key});

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
              child: PinnedHeroBar(opacity: _bar, title: 'Rules'),
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
        sliver: SliverList.separated(
          itemCount: table.rules.length,
          separatorBuilder: (_, _) => SizedBox(height: 12.h),
          itemBuilder: (context, i) {
            final rule = table.rules[i];
            return _RuleCard(
              rule: rule,
              highest: table.highest,
              isHighest: rule.points == table.highest,
            ).slideInAt(i, distance: 18);
          },
        ),
      ),
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
      sliver: SliverList.separated(
        itemCount: 5,
        separatorBuilder: (_, _) => SizedBox(height: 12.h),
        itemBuilder: (_, _) => ShimmerBox(
          width: double.infinity,
          height: 92.h,
          borderRadius: 22.r,
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
      boxShadow: [
        BoxShadow(
          color: AppColors.shadow.withValues(alpha: 0.5),
          blurRadius: 14,
          offset: const Offset(0, 5),
        ),
      ],
    );

class _RuleCard extends StatelessWidget {
  final PointsRule rule;

  /// The best any prayer earns, so each bar can show its share of it.
  final int highest;

  /// The top-earning prayer(s) get a gold look and a badge.
  final bool isHighest;

  const _RuleCard({
    required this.rule,
    required this.highest,
    required this.isHighest,
  });

  @override
  Widget build(BuildContext context) {
    final prayer = rule.prayerName;
    final name = prayer?.label ?? _capitalize(rule.prayer);
    final accent = isHighest ? AppColors.gold : AppColors.emeraldInk;
    final fraction = highest == 0
        ? 0.0
        : (rule.points / highest).clamp(0.0, 1.0);

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: _cardDecoration(
        border: isHighest ? AppColors.gold : null,
        borderWidth: isHighest ? 1.6 : 1,
      ),
      child: Row(
        children: [
          Container(
            width: 50.w,
            height: 50.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isHighest
                    ? [AppColors.goldLight, AppColors.gold]
                    : [AppColors.emeraldInk, AppColors.emeraldInkDark],
              ),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              prayer?.icon ?? Icons.mosque_rounded,
              size: 24.sp,
              color: Colors.white,
            ),
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
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w800,
                          color: AppColors.inkText,
                        ),
                      ),
                    ),
                    if (isHighest) ...[
                      SizedBox(width: 8.w),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 7.w,
                          vertical: 2.h,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.gold.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        child: Text(
                          'HIGHEST',
                          style: TextStyle(
                            fontSize: 8.5.sp,
                            letterSpacing: 0.8,
                            fontWeight: FontWeight.w800,
                            color: AppColors.amberDeep,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (prayer != null) ...[
                  SizedBox(height: 2.h),
                  Text(
                    _window(prayer),
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
                SizedBox(height: 10.h),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6.r),
                  child: Stack(
                    children: [
                      Container(height: 6.h, color: AppColors.borderWarm),
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: fraction),
                        duration: context.motion.duration(AppMotion.value),
                        curve: AppMotion.entrance,
                        builder: (_, v, _) => FractionallySizedBox(
                          widthFactor: v,
                          child: Container(
                            height: 6.h,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: isHighest
                                    ? [AppColors.goldLight, AppColors.gold]
                                    : [
                                        AppColors.emeraldInk,
                                        AppColors.emeraldInkDark,
                                      ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 14.w),
          Container(
            width: 62.w,
            padding: EdgeInsets.symmetric(vertical: 8.h),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16.r),
            ),
            child: Column(
              children: [
                Text(
                  '+${rule.points}',
                  style: TextStyle(
                    fontSize: 22.sp,
                    fontWeight: FontWeight.w800,
                    color: isHighest
                        ? AppColors.amberDeep
                        : AppColors.emeraldInk,
                    height: 1.1,
                  ),
                ),
                Text(
                  rule.points == 1 ? 'point' : 'points',
                  style: TextStyle(
                    fontSize: 10.sp,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// The time each prayer can be logged in (what the server enforces).
  static String _window(PrayerName prayer) => switch (prayer) {
    PrayerName.fajr => 'Log it from Fajr until sunrise',
    PrayerName.dhuhr => 'Log it from Dhuhr until Asr',
    PrayerName.asr => 'Log it from Asr until Maghrib',
    PrayerName.maghrib => 'Log it from Maghrib until Isha',
    PrayerName.isha => 'Log it from Isha until the next Fajr',
  };

  static String _capitalize(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
}

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
