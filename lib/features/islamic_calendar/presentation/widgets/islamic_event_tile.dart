import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/entities/islamic_event.dart';
import '../../domain/entities/islamic_month.dart';

class IslamicEventTile extends StatelessWidget {
  final IslamicEvent event;
  final List<IslamicMonth> months;

  const IslamicEventTile({
    super.key,
    required this.event,
    required this.months,
  });

  @override
  Widget build(BuildContext context) {
    final monthName = months
        .firstWhere((m) => m.number == event.month, orElse: () => months.first)
        .nameEnglish;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20.w, vertical: 6.h),
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: AppColors.borderWarm),
      ),
      child: Row(
        children: [
          Container(
            width: 46.w,
            height: 46.w,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.hijriAccentBg,
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${event.day}',
                  style: AppTypography.titleMedium.copyWith(
                    color: AppColors.hijriAccent,
                  ),
                ),
                Text(
                  monthName.substring(0, 3),
                  style: AppTypography.caption.copyWith(
                    color: AppColors.hijriAccent,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.name,
                  style: AppTypography.titleMedium.copyWith(
                    color: AppColors.inkText,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  event.description,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
