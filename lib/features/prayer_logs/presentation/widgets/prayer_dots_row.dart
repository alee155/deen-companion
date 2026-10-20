import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../prayer_times/domain/entities/prayer_times.dart';
import '../../domain/group_member_prayers.dart';
import '../prayer_labels.dart';
import 'snap_photo_viewer.dart';

/// Five circles, Fajr to Isha: filled with a check for each prayer the member
/// logged on the requested day. Tapping a logged prayer that has a photo opens
/// it. Shown on each member's card in the group.
class PrayerDotsRow extends StatelessWidget {
  final GroupMemberPrayers member;

  /// Diameter of each circle.
  final double size;

  /// Whether a tap opens the photo. False on the viewer's own card: the sender
  /// has no need to open their own snap, and the circles then only show
  /// progress.
  final bool viewable;

  /// Names each circle (Fajr … Isha) and spreads them across the full width.
  /// Off for a compact row; on where there is room, such as the member sheet.
  final bool showLabels;

  const PrayerDotsRow({
    super.key,
    required this.member,
    this.size = 22,
    this.viewable = true,
    this.showLabels = false,
  });

  @override
  Widget build(BuildContext context) {
    Widget dot(PrayerName p) =>
        _Dot(member: member, prayer: p, size: size, viewable: viewable);

    if (showLabels) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (final p in PrayerName.values)
            Column(
              children: [
                dot(p),
                SizedBox(height: 5.h),
                Text(
                  p.label,
                  style: TextStyle(
                    fontSize: 10.5.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < PrayerName.values.length; i++) ...[
          if (i > 0) SizedBox(width: 6.w),
          dot(PrayerName.values[i]),
        ],
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  final GroupMemberPrayers member;
  final PrayerName prayer;
  final double size;
  final bool viewable;
  const _Dot({
    required this.member,
    required this.prayer,
    required this.size,
    required this.viewable,
  });

  @override
  Widget build(BuildContext context) {
    final log = member.logFor(prayer);
    final done = log != null;
    final url = log?.snapUrl;
    return Semantics(
      label: '${prayer.label} ${done ? 'logged' : 'not logged'}',
      child: GestureDetector(
        onTap: url == null || !viewable
            ? null
            : () => showSnapPhoto(
                context,
                url: url,
                title: '${member.displayName} · ${prayer.label}',
                duration: log!.viewDuration(),
              ),
        child: Container(
          width: size.w,
          height: size.w,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: done ? AppColors.emeraldInk : Colors.transparent,
            border: Border.all(
              color: done ? AppColors.emeraldInk : AppColors.borderWarm,
              width: 1.4,
            ),
          ),
          child: done
              ? Icon(
                  Icons.check_rounded,
                  size: size * 0.6.sp,
                  color: AppColors.onEmeraldInk,
                )
              : null,
        ),
      ),
    );
  }
}
