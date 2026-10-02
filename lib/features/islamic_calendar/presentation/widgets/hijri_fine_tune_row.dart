import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/motion/motion.dart';
import '../../../../core/theme/app_colors.dart';
import '../providers/hijri_adjustment_provider.dart';

/// A − / + stepper for the Hijri offset, so a date that differs from the
/// local moon-sighting announcement can be corrected by exactly the number
/// of days it is off. Shared by Settings and the calendar's adjustment sheet,
/// and writes the same provider as the presets.
class HijriFineTuneRow extends ConsumerWidget {
  const HijriFineTuneRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offset = ref.watch(hijriAdjustmentProvider);
    final notifier = ref.read(hijriAdjustmentProvider.notifier);

    final label = offset == 0
        ? 'Calculated date'
        : '${offset.abs()} day${offset.abs() == 1 ? '' : 's'} '
              '${offset < 0 ? 'behind' : 'ahead of'} calculated';

    Widget step(IconData icon, bool enabled, int delta) => PressScale(
      enabled: enabled,
      child: InkResponse(
        onTap: enabled
            ? () {
                HapticFeedback.selectionClick();
                notifier.setOffset(offset + delta);
              }
            : null,
        radius: 24.r,
        child: Container(
          width: 38.w,
          height: 38.w,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: enabled ? AppColors.worshipAccentBg : AppColors.borderWarm,
          ),
          child: Icon(
            icon,
            size: 20.sp,
            color: enabled ? AppColors.worshipAccent : AppColors.textMuted,
          ),
        ),
      ),
    );

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.borderWarm),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Fine-tune',
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w800,
                    color: AppColors.inkText,
                  ),
                ),
                SizedBox(height: 2.h),
                AnimatedText(
                  label,
                  style: TextStyle(
                    fontSize: 11.5.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.worshipAccent,
                  ),
                ),
              ],
            ),
          ),
          step(
            Icons.remove_rounded,
            offset > HijriAdjustmentNotifier.minOffset,
            -1,
          ),
          SizedBox(width: 8.w),
          step(
            Icons.add_rounded,
            offset < HijriAdjustmentNotifier.maxOffset,
            1,
          ),
        ],
      ),
    );
  }
}
