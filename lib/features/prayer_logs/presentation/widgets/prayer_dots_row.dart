import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../prayer_times/domain/entities/prayer_times.dart';
import '../../domain/group_member_prayers.dart';
import '../../domain/prayer_log.dart';
import '../prayer_labels.dart';
import '../snap_viewing.dart';
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

  /// When set, the opened photo has a ⋯ menu (report / block), and this is told
  /// which prayer's photo and what was chosen. Null on the viewer's own row.
  final void Function(PrayerLog log, SnapViewerAction action)? onSnapAction;

  const PrayerDotsRow({
    super.key,
    required this.member,
    this.size = 22,
    this.viewable = true,
    this.showLabels = false,
    this.onSnapAction,
  });

  @override
  Widget build(BuildContext context) {
    Widget dot(PrayerName p) => _Dot(
      member: member,
      prayer: p,
      size: size,
      viewable: viewable,
      onSnapAction: onSnapAction,
    );

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

class _Dot extends ConsumerWidget {
  final GroupMemberPrayers member;
  final PrayerName prayer;
  final double size;
  final bool viewable;
  final void Function(PrayerLog log, SnapViewerAction action)? onSnapAction;
  const _Dot({
    required this.member,
    required this.prayer,
    required this.size,
    required this.viewable,
    required this.onSnapAction,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final log = member.logFor(prayer);
    final done = log != null;
    final hasSnap =
        log != null && log.snapState(DateTime.now()) != SnapState.none;
    return Semantics(
      label: '${prayer.label} ${done ? 'logged' : 'not logged'}',
      child: GestureDetector(
        onTap: !hasSnap || !viewable
            ? null
            : () async {
                final action = await openMemberSnap(
                  context,
                  ref,
                  log: log,
                  title: '${member.displayName} · ${prayer.label}',
                  canModerate: onSnapAction != null,
                );
                if (action != null) onSnapAction?.call(log, action);
              },
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
