import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/motion/motion.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/reliability_requirement.dart';
import '../providers/reliability_providers.dart';
import 'reliability_setup_sheet.dart';

/// Standing reminder on Home while any requirement is still missing, so a
/// declined (or later revoked) permission is never discovered when an alert
/// fails to fire. Disappears by itself once everything is allowed.
class ReliabilityBanner extends ConsumerWidget {
  const ReliabilityBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final missing =
        ref.watch(reliabilityStatusProvider).value?.missing ?? const [];

    return ExpandSection(
      expanded: missing.isNotEmpty,
      child: Padding(
        padding: EdgeInsets.only(bottom: 16.h),
        child: PressScale(
          child: Material(
            color: AppColors.worshipAccentBg,
            borderRadius: BorderRadius.circular(22.r),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => showReliabilitySetupSheet(context),
              child: Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22.r),
                  border: Border.all(
                    color: AppColors.emeraldInk.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42.w,
                      height: 42.w,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(14.r),
                      ),
                      child: Icon(
                        Icons.alarm_on_rounded,
                        size: 22.sp,
                        color: AppColors.worshipAccent,
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Finish setup for on-time reminders',
                            style: TextStyle(
                              fontSize: 13.5.sp,
                              fontWeight: FontWeight.w800,
                              color: AppColors.inkText,
                            ),
                          ),
                          SizedBox(height: 2.h),
                          Text(
                            '${missing.length} permission'
                            '${missing.length == 1 ? '' : 's'} still needed',
                            style: TextStyle(
                              fontSize: 11.5.sp,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 22.sp,
                      color: AppColors.worshipAccent,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
