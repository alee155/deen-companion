import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../core/motion/motion.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_motion.dart';
import '../../core/theme/app_typography.dart';

/// The controls under a screen that pages through a list (hadith, the Names of
/// Allah): a round button each way and, between them, where you are, as
/// "12 of 99" over a progress line.
///
/// Give [onSeek] to make the line draggable, to jump around a long list.
class PagerControls extends StatelessWidget {
  final int page;
  final int count;
  final bool isLoadingMore;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final ValueChanged<int>? onSeek;

  /// The accent for the number and the line. Defaults to the app's green.
  final Color? accent;

  const PagerControls({
    super.key,
    required this.page,
    required this.count,
    this.isLoadingMore = false,
    this.onPrevious,
    this.onNext,
    this.onSeek,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 6.h, 20.w, 12.h),
      child: Row(
        children: [
          PagerButton(
            icon: Icons.arrow_back_rounded,
            tooltip: 'Previous',
            onPressed: onPrevious,
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: _Position(
              page: page,
              count: count,
              isLoadingMore: isLoadingMore,
              onSeek: onSeek,
              accent: accent ?? AppColors.emeraldInk,
            ),
          ),
          SizedBox(width: 12.w),
          PagerButton(
            icon: Icons.arrow_forward_rounded,
            tooltip: 'Next',
            onPressed: onNext,
          ),
        ],
      ),
    );
  }
}

class _Position extends StatelessWidget {
  final int page;
  final int count;
  final bool isLoadingMore;
  final ValueChanged<int>? onSeek;
  final Color accent;

  const _Position({
    required this.page,
    required this.count,
    required this.isLoadingMore,
    required this.onSeek,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final seek = onSeek != null && count > 1;
    return Container(
      height: 48.h,
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: AppColors.borderWarm),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${page + 1}',
                style: AppTypography.titleMedium.copyWith(
                  color: AppColors.hadithAccent,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                '  of $count',
                style: AppTypography.titleMedium.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (isLoadingMore) ...[
                SizedBox(width: 8.w),
                SizedBox(
                  width: 12.w,
                  height: 12.w,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: accent,
                  ),
                ),
              ],
            ],
          ),
          SizedBox(height: seek ? 0 : 5.h),
          if (seek)
            SizedBox(
              height: 14.h,
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 3,
                  activeTrackColor: accent,
                  inactiveTrackColor: AppColors.borderWarm,
                  thumbColor: AppColors.gold,
                  overlayShape: SliderComponentShape.noOverlay,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 6,
                  ),
                  trackShape: const RoundedRectSliderTrackShape(),
                ),
                child: Slider(
                  min: 0,
                  max: (count - 1).toDouble(),
                  value: page.clamp(0, count - 1).toDouble(),
                  onChanged: (v) => onSeek!(v.round()),
                ),
              ),
            )
          else
            ClipRRect(
              borderRadius: BorderRadius.circular(2.r),
              child: LinearProgressIndicator(
                minHeight: 3.h,
                value: count == 0 ? 0 : (page + 1) / count,
                backgroundColor: AppColors.borderWarm,
                color: accent,
              ),
            ),
        ],
      ),
    );
  }
}

/// A round previous/next button: solid when it can be used, pale when not.
class PagerButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  const PagerButton({
    super.key,
    required this.icon,
    required this.tooltip,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Pressable(
      onTap: onPressed,
      child: Semantics(
        button: true,
        enabled: enabled,
        label: tooltip,
        child: AnimatedContainer(
          duration: context.motion.duration(AppMotion.fast),
          width: 48.w,
          height: 48.w,
          decoration: BoxDecoration(
            color: enabled ? AppColors.emeraldInk : AppColors.surfaceLight,
            shape: BoxShape.circle,
            border: Border.all(
              color: enabled ? AppColors.emeraldInk : AppColors.borderWarm,
            ),
          ),
          child: Icon(
            icon,
            size: 22.sp,
            color: enabled ? AppColors.onEmeraldInk : AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}
