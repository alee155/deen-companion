import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/motion/motion.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/islamic_ornaments.dart';

class EmptyGroups extends StatelessWidget {
  final bool isSearching;
  final VoidCallback onCreateGroup;

  const EmptyGroups({
    super.key,
    required this.isSearching,
    required this.onCreateGroup,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 32.h),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: AppColors.borderWarm),
      ),
      child: Column(
        children: [
          SizedBox(
            width: 84.w,
            height: 84.w,
            child: CustomPaint(
              painter: StarPainter(
                fill: AppColors.worshipAccentBg,
                stroke: AppColors.worshipAccent.withValues(alpha: 0.5),
                inner: 0.76,
              ),
              child: Icon(
                isSearching ? Icons.search_off_rounded : Icons.groups_rounded,
                color: AppColors.worshipAccent,
                size: 32.sp,
              ),
            ),
          ).slideIn(RevealDirection.top),
          SizedBox(height: 16.h),
          Text(
            isSearching ? 'No matching groups' : 'No groups yet',
            style: TextStyle(
              fontSize: 17.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.inkText,
            ),
          ).slideIn(
            RevealDirection.bottom,
            delay: const Duration(milliseconds: 60),
          ),
          SizedBox(height: 6.h),
          Text(
            isSearching
                ? 'Try a different name or description.'
                : 'Create a Quran group and build a streak together.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.sp,
              height: 1.4,
              color: AppColors.textSecondary,
            ),
          ).slideIn(
            RevealDirection.top,
            delay: const Duration(milliseconds: 120),
          ),
          if (!isSearching) ...[
            SizedBox(height: 18.h),
            FilledButton.icon(
              onPressed: onCreateGroup,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.heroSurface,
                foregroundColor: AppColors.goldLight,
                padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16.r),
                ),
              ),
              icon: const Icon(Icons.add_rounded),
              label: Text(
                'Create group',
                style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700),
              ),
            ).slideIn(
              RevealDirection.bottom,
              delay: const Duration(milliseconds: 180),
            ),
          ],
        ],
      ),
    );
  }
}
