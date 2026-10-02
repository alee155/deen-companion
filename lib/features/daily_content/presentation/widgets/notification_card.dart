import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import '../../../../core/motion/motion.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/domain/explore_icon_assets.dart';
import '../providers/daily_content_providers.dart';

/// One delivered notification, built like the Group cards: a 22px bordered
/// surface, the Explore Quran icon as the leading tile with the Explore
/// Hadith icon pinned to its corner (the notification carries both), and a
/// compact two-line preview. Unread is a tinted card with an orange dot.
class NotificationCard extends StatelessWidget {
  final DailyNotificationRecord record;
  final VoidCallback onTap;

  const NotificationCard({
    super.key,
    required this.record,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final unread = !record.read;
    final lines = record.preview.split('\n');

    return PressScale(
      child: Material(
        color: unread
            ? Color.alphaBlend(
                AppColors.emeraldInk.withValues(alpha: 0.05),
                AppColors.surfaceLight,
              )
            : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(22.r),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22.r),
              border: Border.all(
                color: unread
                    ? AppColors.emeraldInk.withValues(alpha: 0.35)
                    : AppColors.borderWarm,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _LeadingIcons(),
                SizedBox(width: 14.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              record.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 15.sp,
                                fontWeight: unread
                                    ? FontWeight.w800
                                    : FontWeight.w700,
                                color: AppColors.inkText,
                              ),
                            ),
                          ),
                          if (record.debug) ...[
                            SizedBox(width: 6.w),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 7.w,
                                vertical: 2.h,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.textMuted.withValues(
                                  alpha: 0.18,
                                ),
                                borderRadius: BorderRadius.circular(8.r),
                              ),
                              child: Text(
                                'TEST',
                                style: TextStyle(
                                  fontSize: 8.5.sp,
                                  letterSpacing: 0.8,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        lines.first,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.sp,
                          height: 1.35,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      SizedBox(height: 8.h),
                      Row(
                        children: [
                          Icon(
                            Icons.schedule_rounded,
                            size: 13.sp,
                            color: AppColors.worshipAccent,
                          ),
                          SizedBox(width: 4.w),
                          Text(
                            DateFormat('h:mm a').format(record.receivedAt),
                            style: TextStyle(
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          if (lines.length > 1) ...[
                            SizedBox(width: 12.w),
                            Icon(
                              Icons.auto_stories_rounded,
                              size: 13.sp,
                              color: AppColors.textMuted,
                            ),
                            SizedBox(width: 4.w),
                            Expanded(
                              child: Text(
                                lines[1].replaceFirst('Hadith: ', ''),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ),
                          ] else
                            const Spacer(),
                          if (unread) ...[
                            SizedBox(width: 8.w),
                            Container(
                              width: 9.w,
                              height: 9.w,
                              decoration: BoxDecoration(
                                color: AppColors.emeraldInk,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ],
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

/// Explore's Quran icon, with its Hadith icon as a corner badge.
class _LeadingIcons extends StatelessWidget {
  const _LeadingIcons();

  @override
  Widget build(BuildContext context) {
    final size = 58.w;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size,
            height: size,
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(18.r),
              border: Border.all(color: AppColors.borderWarm, width: 1.2.w),
            ),
            child: Image.asset(
              exploreIconAssets['quran']!,
              fit: BoxFit.contain,
            ),
          ),
          Positioned(
            right: -6.w,
            bottom: -6.w,
            child: Container(
              width: 26.w,
              height: 26.w,
              padding: EdgeInsets.all(4.w),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.borderWarm, width: 1.2.w),
              ),
              child: Image.asset(
                exploreIconAssets['hadith']!,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
