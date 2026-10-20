import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/motion/motion.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/failure_view.dart';
import '../../../../shared/widgets/islamic_ornaments.dart';
import '../../domain/bars_model.dart';
import '../../domain/entities/stats_common.dart';
import '../providers/chart_providers.dart';
import '../providers/statistics_providers.dart';

/// "62%", or a dash for a day with no data (never a made-up 0%).
String percentOrDash(double? v) => v == null ? '–' : '${v.round()}%';

/// The statistics chart, in the same dark panel as the points chart on the
/// Rules screen: who is shown (Group, You or a member), a bar for each day,
/// what the chosen day says in words, and how far back to look.
class StatsChartPanel extends ConsumerStatefulWidget {
  final String groupId;

  /// The name to show on the third pill when a member is chosen.
  final String? memberName;

  const StatsChartPanel({super.key, required this.groupId, this.memberName});

  @override
  ConsumerState<StatsChartPanel> createState() => _StatsChartPanelState();
}

class _StatsChartPanelState extends ConsumerState<StatsChartPanel> {
  /// The day pointed at; null means today.
  int? _picked;

  @override
  Widget build(BuildContext context) {
    final subject = ref.watch(statsSubjectProvider);
    final bars = ref.watch(statsBarsProvider(widget.groupId));

    // A new subject or period starts again from today.
    ref.listen(statsSubjectProvider, (_, _) => setState(() => _picked = null));
    ref.listen(statsPeriodProvider, (_, _) => setState(() => _picked = null));

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: AppColors.heroGradient,
        ),
        borderRadius: BorderRadius.circular(28.r),
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
            padding: EdgeInsets.all(18.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SubjectPills(subject: subject, memberName: widget.memberName),
                SizedBox(height: 16.h),
                bars.when(
                  loading: () => SizedBox(
                    height: 230.h,
                    child: const Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  error: (e, _) => _Failed(
                    failure: failureFrom(e),
                    onRetry: () => _retry(subject),
                  ),
                  data: (model) {
                    if (model.isEmpty) return const _Empty();
                    final selected = (_picked ?? model.todayIndex).clamp(
                      0,
                      model.days.length - 1,
                    );
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _Bars(
                          days: model.days,
                          selected: selected,
                          onSelect: (i) => setState(() => _picked = i),
                        ),
                        SizedBox(height: 14.h),
                        _Caption(
                          day: model.days[selected],
                          average: model.average,
                        ),
                      ],
                    );
                  },
                ),
                SizedBox(height: 14.h),
                const _PeriodChips(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _retry(StatsSubject subject) {
    switch (subject) {
      case GroupSubject():
        ref.invalidate(groupOverviewProvider(widget.groupId));
      case MeSubject():
        ref.invalidate(myDailyProvider);
      case MemberSubject(:final userId):
        ref.invalidate(
          memberStatsDetailProvider((groupId: widget.groupId, userId: userId)),
        );
    }
  }
}

class _SubjectPills extends ConsumerWidget {
  final StatsSubject subject;
  final String? memberName;
  const _SubjectPills({required this.subject, required this.memberName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void pick(StatsSubject s) {
      if (s == subject) return;
      HapticFeedback.selectionClick();
      ref.read(statsSubjectProvider.notifier).state = s;
    }

    return Wrap(
      spacing: 8.w,
      runSpacing: 8.h,
      children: [
        _Pill(
          label: 'Group',
          selected: subject is GroupSubject,
          onTap: () => pick(StatsSubject.group),
        ),
        _Pill(
          label: 'You',
          selected: subject is MeSubject,
          onTap: () => pick(StatsSubject.me),
        ),
        // A member chosen from the list below.
        if (subject is MemberSubject)
          _Pill(label: memberName ?? 'Member', selected: true, onTap: () {}),
      ],
    );
  }
}

/// A frosted pill; the chosen one is filled, as the chosen bar is gold.
class _Pill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Pill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: Pressable(
        onTap: onTap,
        scale: 0.96,
        child: AnimatedContainer(
          duration: context.motion.duration(AppMotion.fast),
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.goldLight
                : Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(18.r),
            border: Border.all(
              color: selected
                  ? AppColors.goldLight
                  : Colors.white.withValues(alpha: 0.2),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13.sp,
              fontWeight: FontWeight.w800,
              color: selected ? const Color(0xFF3A2A0E) : Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

/// A bar per day, 0–100 %, on one axis from zero. The chosen day is gold and
/// today (not over yet) is lighter. Tap or drag to choose a day.
class _Bars extends StatelessWidget {
  final List<DayBar> days;
  final int selected;
  final ValueChanged<int> onSelect;

  const _Bars({
    required this.days,
    required this.selected,
    required this.onSelect,
  });

  void _pick(double dx, double width) {
    final i = (dx / width * days.length).floor().clamp(0, days.length - 1);
    if (i != selected) {
      HapticFeedback.selectionClick();
      onSelect(i);
    }
  }

  @override
  Widget build(BuildContext context) {
    final gap = days.length > 40 ? 1.0 : 3.0;
    return Semantics(
      label: 'Daily chart. Drag to choose a day.',
      child: Column(
        children: [
          LayoutBuilder(
            builder: (context, c) => GestureDetector(
              key: const Key('stats-bars'),
              behavior: HitTestBehavior.opaque,
              onTapDown: (d) => _pick(d.localPosition.dx, c.maxWidth),
              onHorizontalDragUpdate: (d) =>
                  _pick(d.localPosition.dx, c.maxWidth),
              child: SizedBox(
                height: 170.h,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final (i, d) in days.indexed)
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: gap / 2),
                          child: _Bar(day: d, selected: i == selected),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          Container(height: 1.5, color: Colors.white.withValues(alpha: 0.28)),
          SizedBox(height: 8.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _axis(DateFormat('d MMM').format(days.first.day)),
              if (days.length > 1)
                _axis(DateFormat('d MMM').format(days.last.day)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _axis(String t) => Text(
    t,
    style: TextStyle(
      fontSize: 11.sp,
      color: AppColors.onHeroSurface.withValues(alpha: 0.7),
    ),
  );
}

class _Bar extends StatelessWidget {
  final DayBar day;
  final bool selected;
  const _Bar({required this.day, required this.selected});

  @override
  Widget build(BuildContext context) {
    final v = day.percent;
    final color = selected
        ? AppColors.goldLight
        : Colors.white.withValues(alpha: day.partial ? 0.22 : 0.4);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: v == null ? 0 : (v / 100).clamp(0.0, 1.0)),
      duration: context.motion.duration(AppMotion.value),
      curve: AppMotion.entrance,
      builder: (_, f, _) => Align(
        alignment: Alignment.bottomCenter,
        child: FractionallySizedBox(
          // No data: a faint stub, so the gap shows but is not read as zero.
          heightFactor: v == null ? null : f.clamp(0.02, 1.0),
          child: Container(
            height: v == null ? 3 : null,
            decoration: BoxDecoration(
              color: v == null ? Colors.white.withValues(alpha: 0.15) : color,
              borderRadius: BorderRadius.vertical(top: Radius.circular(5.r)),
            ),
          ),
        ),
      ),
    );
  }
}

/// What the chosen day says, in words: the date, the number, and what it
/// means — in the frosted strip the points chart uses.
class _Caption extends StatelessWidget {
  final DayBar day;
  final double? average;
  const _Caption({required this.day, required this.average});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${DateFormat('EEE d MMM').format(day.day)}'
                  '${day.partial ? ' · today, so far' : ''}',
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  day.detail,
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: AppColors.onHeroSurface.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 12.w),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                percentOrDash(day.percent),
                style: TextStyle(
                  fontSize: 22.sp,
                  fontWeight: FontWeight.w800,
                  color: AppColors.goldLight,
                  height: 1.1,
                ),
              ),
              if (average != null)
                Text(
                  'avg ${percentOrDash(average)}',
                  style: TextStyle(
                    fontSize: 10.5.sp,
                    color: AppColors.onHeroSurface.withValues(alpha: 0.7),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 7D · 30D · 90D, in the same frosted pills.
class _PeriodChips extends ConsumerWidget {
  const _PeriodChips();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(statsPeriodProvider);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final p in StatsPeriod.values)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 4.w),
            child: Semantics(
              button: true,
              selected: p == current,
              label: p.label,
              excludeSemantics: true,
              child: Pressable(
                onTap: () => ref.read(statsPeriodProvider.notifier).state = p,
                haptic: p != current,
                scale: 0.96,
                child: AnimatedContainer(
                  duration: context.motion.duration(AppMotion.fast),
                  padding: EdgeInsets.symmetric(
                    horizontal: 14.w,
                    vertical: 6.h,
                  ),
                  decoration: BoxDecoration(
                    color: p == current
                        ? Colors.white.withValues(alpha: 0.22)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(14.r),
                    border: Border.all(
                      color: Colors.white.withValues(
                        alpha: p == current ? 0.5 : 0.18,
                      ),
                    ),
                  ),
                  child: Text(
                    p.short.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11.5.sp,
                      fontWeight: FontWeight.w800,
                      color: Colors.white.withValues(
                        alpha: p == current ? 1 : 0.7,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200.h,
      child: Center(
        child: Text(
          'Nothing to chart yet.\nCome back after a day or two.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13.sp,
            height: 1.4,
            color: AppColors.onHeroSurface.withValues(alpha: 0.85),
          ),
        ),
      ),
    );
  }
}

class _Failed extends StatelessWidget {
  final Failure failure;
  final VoidCallback onRetry;
  const _Failed({required this.failure, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200.h,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            failure.message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.sp,
              height: 1.4,
              color: AppColors.onHeroSurface.withValues(alpha: 0.9),
            ),
          ),
          SizedBox(height: 8.h),
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(foregroundColor: AppColors.goldLight),
            child: const Text('Try again'),
          ),
        ],
      ),
    );
  }
}
