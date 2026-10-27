import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/motion/motion.dart';
import '../../../../core/theme/app_colors.dart';
import 'player_scrubber.dart';

const _sheetColor = Color(0xFF211A15);

/// Speeds offered. Recitation is clearest between these two ends.
const playerSpeeds = [0.75, 1.0, 1.25, 1.5];

/// Sleep-timer lengths.
const sleepTimerOptions = [
  Duration(minutes: 5),
  Duration(minutes: 15),
  Duration(minutes: 30),
  Duration(minutes: 45),
  Duration(minutes: 60),
  Duration(minutes: 90),
];

/// `1.0` -> `1×`, `1.25` -> `1.25×`.
String speedLabel(double speed) =>
    '${speed == speed.roundToDouble() ? speed.toInt() : speed}×';

Future<void> showSpeedSheet(
  BuildContext context, {
  required double current,
  required ValueChanged<double> onSelect,
}) {
  return _show(
    context,
    title: 'Playback speed',
    subtitle: 'Slower to follow along, faster to revise.',
    rows: [
      for (final s in playerSpeeds)
        _Row(
          label: s == 1.0 ? 'Normal (1×)' : speedLabel(s),
          selected: s == current,
          onTap: (sheet) {
            Navigator.of(sheet).pop();
            onSelect(s);
          },
        ),
    ],
  );
}

Future<void> showSleepTimerSheet(
  BuildContext context, {
  required Duration? remaining,
  required ValueChanged<Duration> onSelect,
  required VoidCallback onTurnOff,
}) {
  return _show(
    context,
    title: 'Sleep timer',
    subtitle: 'Recitation stops by itself once the time is up.',
    rows: [
      if (remaining != null)
        _Row(
          label: 'Turn off (${formatPlayerTime(remaining)} left)',
          destructive: true,
          onTap: (sheet) {
            Navigator.of(sheet).pop();
            onTurnOff();
          },
        ),
      for (final d in sleepTimerOptions)
        _Row(
          label: '${d.inMinutes} minutes',
          onTap: (sheet) {
            Navigator.of(sheet).pop();
            onSelect(d);
          },
        ),
    ],
  );
}

Future<void> _show(
  BuildContext context, {
  required String title,
  required String subtitle,
  required List<_Row> rows,
}) {
  return showModalBottomSheet<void>(
    sheetAnimationStyle: AppMotion.sheetStyle,
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheet) => Container(
      decoration: BoxDecoration(
        color: _sheetColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26.r)),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20.w, 10.h, 20.w, 12.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 38.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
              ),
              SizedBox(height: 16.h),
              Text(
                title,
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w800,
                  color: AppColors.onHeroSurface,
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12.5.sp,
                  color: AppColors.onHeroSurface.withValues(alpha: 0.6),
                ),
              ),
              SizedBox(height: 10.h),
              for (final r in rows) r.build(sheet),
            ],
          ),
        ),
      ),
    ),
  );
}

class _Row {
  final String label;
  final bool selected;
  final bool destructive;
  final void Function(BuildContext sheet) onTap;
  const _Row({
    required this.label,
    required this.onTap,
    this.selected = false,
    this.destructive = false,
  });

  Widget build(BuildContext sheet) {
    final color = destructive
        ? const Color(0xFFFF8A7A)
        : selected
        ? AppColors.goldLight
        : AppColors.onHeroSurface;
    return InkWell(
      borderRadius: BorderRadius.circular(14.r),
      onTap: () => onTap(sheet),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 14.h, horizontal: 4.w),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15.sp,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: color,
                ),
              ),
            ),
            if (selected)
              Icon(Icons.check_rounded, size: 20.sp, color: AppColors.amber),
          ],
        ),
      ),
    );
  }
}
