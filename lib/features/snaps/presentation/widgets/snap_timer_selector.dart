import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/snap_draft.dart';

/// "View for" chips: how long a member can look at the snap once opened.
class SnapTimerSelector extends StatelessWidget {
  final int seconds;
  final ValueChanged<int> onChanged;

  const SnapTimerSelector({
    super.key,
    required this.seconds,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.hourglass_bottom_rounded,
              size: 15.sp,
              color: AppColors.emeraldInk,
            ),
            SizedBox(width: 6.w),
            Text(
              'View for',
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.w700,
                color: Colors.white.withValues(alpha: 0.85),
              ),
            ),
          ],
        ),
        SizedBox(height: 8.h),
        Row(
          children: [
            for (final s in SnapViewTimer.options) ...[
              Expanded(
                child: _Chip(
                  seconds: s,
                  selected: s == seconds,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onChanged(s);
                  },
                ),
              ),
              if (s != SnapViewTimer.options.last) SizedBox(width: 8.w),
            ],
          ],
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final int seconds;
  final bool selected;
  final VoidCallback onTap;
  const _Chip({
    required this.seconds,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '$seconds seconds',
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          height: 38.h,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14.r),
            color: selected
                ? AppColors.emeraldInk
                : Colors.white.withValues(alpha: 0.1),
            border: Border.all(
              color: selected
                  ? AppColors.emeraldInk
                  : Colors.white.withValues(alpha: 0.18),
            ),
          ),
          child: Text(
            '${seconds}s',
            style: TextStyle(
              fontSize: 13.sp,
              fontWeight: FontWeight.w800,
              color: selected ? AppColors.onEmeraldInk : Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
