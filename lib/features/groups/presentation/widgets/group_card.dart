import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/motion/motion.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/group.dart';
import 'group_image.dart';

class GroupCard extends StatelessWidget {
  final Group group;
  final VoidCallback onTap;

  const GroupCard({super.key, required this.group, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return PressScale(
      child: Material(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(22.r),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22.r),
              border: Border.all(color: AppColors.borderWarm),
            ),
            child: Row(
              children: [
                GroupImage(path: group.imagePath, size: 72.w, radius: 18.r),
                SizedBox(width: 14.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              group.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 15.sp,
                                fontWeight: FontWeight.w700,
                                color: AppColors.inkText,
                              ),
                            ),
                          ),
                          if (group.isOwner) ...[
                            SizedBox(width: 6.w),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 7.w,
                                vertical: 2.h,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.gold.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(8.r),
                              ),
                              child: Text(
                                'OWNER',
                                style: TextStyle(
                                  fontSize: 8.5.sp,
                                  letterSpacing: 0.8,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.gold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        group.description,
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
                            Icons.people_alt_rounded,
                            size: 14.sp,
                            color: AppColors.worshipAccent,
                          ),
                          SizedBox(width: 4.w),
                          AnimatedCount(
                            value: group.memberCount,
                            style: TextStyle(
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          SizedBox(width: 12.w),
                          Icon(
                            group.isPrivate
                                ? Icons.lock_rounded
                                : Icons.public_rounded,
                            size: 13.sp,
                            color: AppColors.textMuted,
                          ),
                          SizedBox(width: 4.w),
                          Text(
                            group.isPrivate ? 'Private' : 'Public',
                            style: TextStyle(
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textMuted,
                            ),
                          ),
                          const Spacer(),
                          Icon(
                            Icons.local_fire_department_rounded,
                            size: 15.sp,
                            color: AppColors.amber,
                          ),
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
