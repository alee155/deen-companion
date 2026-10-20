import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/motion/motion.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../shared/widgets/islamic_ornaments.dart';
import '../../../prayer_logs/presentation/prayer_labels.dart';
import '../../../prayer_times/domain/entities/prayer_times.dart';
import '../../domain/entities/points_rule.dart';

/// The points each prayer earns as one bar chart, in the same hero style as the
/// feature headers (gradient, faint lattice).
///
/// One measure on one axis from zero, so bar height is directly comparable;
/// one colour for every bar, with the selected one lifted to gold (the best
/// prayer to begin with). Tapping a bar selects it and the line underneath says
/// when that prayer can be logged. Every bar is labelled with its value, so
/// nothing depends on reading the height alone.
class PointsChart extends StatefulWidget {
  final PointsRules table;
  const PointsChart({super.key, required this.table});

  /// The time each prayer can be logged in (what the server enforces).
  static String windowText(PrayerName prayer) => switch (prayer) {
    PrayerName.fajr => 'Log it from Fajr until sunrise',
    PrayerName.dhuhr => 'Log it from Dhuhr until Asr',
    PrayerName.asr => 'Log it from Asr until Maghrib',
    PrayerName.maghrib => 'Log it from Maghrib until Isha',
    PrayerName.isha => 'Log it from Isha until the next Fajr',
  };

  static String labelOf(PointsRule rule) =>
      rule.prayerName?.label ??
      (rule.prayer.isEmpty
          ? rule.prayer
          : '${rule.prayer[0].toUpperCase()}${rule.prayer.substring(1)}');

  @override
  State<PointsChart> createState() => _PointsChartState();
}

class _PointsChartState extends State<PointsChart> {
  int? _picked;

  List<PointsRule> get _rules => widget.table.rules;

  /// The tapped bar, or the first of the best-earning ones.
  int get _selected {
    final picked = _picked;
    if (picked != null && picked < _rules.length) return picked;
    final i = _rules.indexWhere((r) => r.points == widget.table.highest);
    return i < 0 ? 0 : i;
  }

  @override
  Widget build(BuildContext context) {
    final rules = _rules;
    final highest = widget.table.highest;
    final selected = _selected;
    final chosen = rules[selected];
    final prayer = chosen.prayerName;

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
            padding: EdgeInsets.fromLTRB(18.w, 18.h, 18.w, 18.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // A Wrap, not a Row: with large text the total drops to its
                // own line instead of squeezing the title to nothing.
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12.w,
                  runSpacing: 2.h,
                  children: [
                    Text(
                      'Points earned per prayer',
                      style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                        color: AppColors.onHeroSurface.withValues(alpha: 0.8),
                      ),
                    ),
                    Text(
                      'Full day ${widget.table.total}',
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w700,
                        color: AppColors.goldLight,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 14.h),
                SizedBox(
                  height: 190.h,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < rules.length; i++)
                        Expanded(
                          child: _Bar(
                            rule: rules[i],
                            fraction: highest == 0
                                ? 0
                                : (rules[i].points / highest).clamp(0.0, 1.0),
                            selected: i == selected,
                            onTap: () => setState(() => _picked = i),
                          ),
                        ),
                    ],
                  ),
                ),
                SizedBox(height: 14.h),
                _Caption(
                  title: PointsChart.labelOf(chosen),
                  points: chosen.points,
                  detail: prayer == null
                      ? null
                      : PointsChart.windowText(prayer),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  final PointsRule rule;
  final double fraction;
  final bool selected;
  final VoidCallback onTap;

  const _Bar({
    required this.rule,
    required this.fraction,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final prayer = rule.prayerName;
    final labelSlot = 22.h;
    final labelGap = 4.h;
    final color = selected
        ? AppColors.goldLight
        : Colors.white.withValues(alpha: 0.38);

    return Semantics(
      button: true,
      selected: selected,
      label:
          '${PointsChart.labelOf(rule)}, ${rule.points} '
          '${rule.points == 1 ? 'point' : 'points'}',
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 5.w),
          child: Column(
            children: [
              Expanded(
                child: LayoutBuilder(
                  builder: (context, c) {
                    // The value label gets a fixed-height slot, so the bar's
                    // room is exact and the column can never overflow by a
                    // fraction of a pixel when the font rounds up.
                    final room = (c.maxHeight - labelSlot - labelGap).clamp(
                      3.0,
                      double.infinity,
                    );
                    return TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: fraction),
                      duration: context.motion.duration(AppMotion.value),
                      curve: AppMotion.entrance,
                      builder: (_, v, _) => Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          SizedBox(
                            height: labelSlot,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                '${rule.points}',
                                style: TextStyle(
                                  fontSize: 15.sp,
                                  fontWeight: FontWeight.w800,
                                  color: selected
                                      ? AppColors.goldLight
                                      : Colors.white,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: labelGap),
                          AnimatedContainer(
                            duration: context.motion.duration(AppMotion.fast),
                            width: double.infinity,
                            // Never fully flat: a 0-point prayer still shows.
                            height: (room * v).clamp(3.0, room),
                            decoration: BoxDecoration(
                              color: color,
                              // Rounded where the data ends, square on the
                              // baseline.
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(8.r),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Container(
                height: 1.5,
                color: Colors.white.withValues(alpha: 0.28),
              ),
              SizedBox(height: 8.h),
              Icon(
                prayer?.icon ?? Icons.mosque_rounded,
                size: 17.sp,
                color: selected
                    ? AppColors.goldLight
                    : Colors.white.withValues(alpha: 0.7),
              ),
              SizedBox(height: 3.h),
              Text(
                PointsChart.labelOf(rule),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.sp,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                  color: selected
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.72),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// What the selected bar means: its name, points, and when it can be logged.
class _Caption extends StatelessWidget {
  final String title;
  final int points;
  final String? detail;

  const _Caption({
    required this.title,
    required this.points,
    required this.detail,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      // A Wrap, so the points drop below the text when large type leaves no
      // room beside it, rather than crushing the window text into a sliver.
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12.w,
        runSpacing: 4.h,
        children: [
          // The highlighted bar already names the prayer; the name is only
          // repeated when there is no window text to show.
          Text(
            detail ?? title,
            style: TextStyle(
              fontSize: 13.sp,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          Text(
            '+$points ${points == 1 ? 'point' : 'points'}',
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w800,
              color: AppColors.goldLight,
            ),
          ),
        ],
      ),
    );
  }
}
