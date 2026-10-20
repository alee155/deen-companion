import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../prayer_logs/domain/current_prayer.dart';
import '../../../prayer_logs/presentation/prayer_labels.dart';

/// Shown in place of the send-snap button when a snap can't be sent right now:
/// either the open prayer is already logged, or no prayer window is open.
/// Says why and when the next chance is, so the missing button isn't a puzzle.
class SnapStatusPill extends StatelessWidget {
  final CurrentPrayerState state;
  const SnapStatusPill({super.key, required this.state});

  /// The two lines to show; the second is null when there is nothing to add.
  static ({String title, String? detail, IconData icon}) message(
    CurrentPrayerState s,
  ) {
    final open = s.current;
    final next = s.next;
    final nextLine = next == null
        ? null
        : 'Next: ${next.prayer.label} at ${clockTime(next.startsAt)}';
    if (open != null && open.logged) {
      return (
        title: '${open.prayer.label} logged',
        detail: nextLine,
        icon: Icons.check_circle_rounded,
      );
    }
    return (
      title: 'No prayer is open right now',
      detail: next == null
          ? null
          : '${next.prayer.label} starts at ${clockTime(next.startsAt)}',
      icon: Icons.schedule_rounded,
    );
  }

  @override
  Widget build(BuildContext context) {
    final m = message(state);
    return Semantics(
      label: [m.title, ?m.detail].join('. '),
      child: ExcludeSemantics(
        child: Container(
          constraints: BoxConstraints(maxWidth: 300.w),
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
          decoration: BoxDecoration(
            color: AppColors.heroSurface,
            borderRadius: BorderRadius.circular(22.r),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(m.icon, size: 22.sp, color: AppColors.goldLight),
              SizedBox(width: 10.w),
              Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      m.title,
                      style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    if (m.detail != null)
                      Text(
                        m.detail!,
                        style: TextStyle(
                          fontSize: 11.5.sp,
                          color: AppColors.onHeroSurface.withValues(alpha: 0.8),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
