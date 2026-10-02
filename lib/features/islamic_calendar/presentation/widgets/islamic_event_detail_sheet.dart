import 'package:flutter/material.dart';
import 'package:deen_companion/core/motion/motion.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/ornament_divider.dart';
import '../../../../shared/widgets/seal_number_badge.dart';
import '../../domain/entities/islamic_event.dart';
import '../../domain/entities/islamic_month.dart';

/// Full detail for one event — event tiles used to be inert; tapping one now
/// opens this instead of doing nothing.
Future<void> showIslamicEventDetailSheet(
  BuildContext context, {
  required IslamicEvent event,
  required IslamicMonth month,
}) {
  return showModalBottomSheet<void>(
    sheetAnimationStyle: AppMotion.sheetStyle,
    context: context,
    backgroundColor: AppColors.surfaceLight,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
    ),
    builder: (context) => _EventDetailContent(event: event, month: month),
  );
}

class _EventDetailContent extends StatelessWidget {
  final IslamicEvent event;
  final IslamicMonth month;

  const _EventDetailContent({required this.event, required this.month});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 24.h),
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
            SizedBox(height: 18.h),
            Row(
              children: [
                SealNumberBadge(
                  number: event.day,
                  size: 48.w,
                  color: AppColors.emeraldInk,
                ),
                SizedBox(width: 14.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.name,
                        style: AppTypography.headline.copyWith(
                          fontSize: 17.sp,
                          color: AppColors.inkText,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        '${event.day} ${month.nameEnglish} · ${month.nameArabic}',
                        textDirection: TextDirection.ltr,
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.emeraldInk,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 18.h),
            OrnamentDivider(ruleWidth: 22.w),
            SizedBox(height: 16.h),
            Text(
              event.description,
              style: AppTypography.bodyLarge.copyWith(
                color: AppColors.inkText,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
