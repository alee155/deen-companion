import 'package:flutter/material.dart';
import 'package:deen_companion/core/motion/motion.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../providers/hijri_adjustment_provider.dart';
import 'hijri_fine_tune_row.dart';

/// Lets the reader choose which Hijri date the app shows — the calculated
/// date the API returns, or the date one day earlier that Pakistan observes.
/// The provider backing this choice already existed; nothing on screen used
/// to expose it, so most people could never find it.
Future<void> showHijriAdjustmentSheet(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<void>(
    sheetAnimationStyle: AppMotion.sheetStyle,
    context: context,
    backgroundColor: AppColors.surfaceLight,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
    ),
    builder: (context) => const _HijriAdjustmentSheetContent(),
  );
}

class _HijriAdjustmentSheetContent extends ConsumerWidget {
  const _HijriAdjustmentSheetContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final adjustment = ref.watch(hijriAdjustmentProvider);
    final notifier = ref.read(hijriAdjustmentProvider.notifier);

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 20.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: AppColors.borderWarm,
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
            ),
            SizedBox(height: 16.h),
            Text(
              'Hijri date adjustment',
              style: AppTypography.headline.copyWith(
                fontSize: 16.sp,
                color: AppColors.inkText,
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              'Moon sighting varies by region, so the observed date can run '
              'a day behind the calculated one.',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            SizedBox(height: 18.h),
            _OptionTile(
              title: 'Automatic',
              description: "Show exactly what today's date calculates to.",
              selected: adjustment == 0,
              onTap: notifier.setAutomatic,
            ),
            SizedBox(height: 10.h),
            _OptionTile(
              title: 'Pakistan',
              description:
                  'One day behind the calculated date — the usual gap to the '
                  "Ruet-e-Hilal Committee's observed date.",
              selected: adjustment == -1,
              onTap: notifier.setPakistan,
            ),
            SizedBox(height: 10.h),
            const HijriFineTuneRow(),
          ],
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final String title;
  final String description;
  final bool selected;
  final VoidCallback onTap;

  const _OptionTile({
    required this.title,
    required this.description,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return PressScale(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14.r),
          onTap: onTap,
          child: Container(
            padding: EdgeInsets.all(14.w),
            decoration: BoxDecoration(
              color: selected ? AppColors.worshipAccentBg : AppColors.parchment,
              borderRadius: BorderRadius.circular(14.r),
              border: Border.all(
                color: selected
                    ? AppColors.emeraldInk.withValues(alpha: 0.5)
                    : AppColors.borderWarm,
                width: selected ? 1.4 : 1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  selected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_off_rounded,
                  size: 20.sp,
                  color: selected ? AppColors.emeraldInk : AppColors.textMuted,
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTypography.titleMedium.copyWith(
                          color: AppColors.inkText,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 3.h),
                      Text(
                        description,
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
