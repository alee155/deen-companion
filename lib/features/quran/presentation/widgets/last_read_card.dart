import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/motion/motion.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/entities/surah_summary.dart';

/// The "Last Read" hero card — shown above the surah list only once there's
/// real history to show (see [lastReadSurahProvider]). "Continue Reading"
/// resumes the recitation audio, since there's no dedicated text-reading
/// screen yet; this is honest about what the app can actually resume.
class LastReadCard extends StatelessWidget {
  final SurahSummary surah;
  final VoidCallback onContinue;

  const LastReadCard({
    super.key,
    required this.surah,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18.r),
      child: Stack(
        children: [
          Image.asset(
            'assets/images/last_read.png',
            fit: BoxFit.cover,
            width: double.infinity,
            height: 150.h,
          ),
          Container(
            width: double.infinity,
            height: 150.h,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.25),
                  Colors.black.withValues(alpha: 0.65),
                ],
              ),
            ),
          ),
          Positioned(
            top: 16.h,
            left: 16.w,
            right: 16.w,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Last Read',
                  style: AppTypography.caption.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ).slideIn(RevealDirection.topStart, distance: 12, fade: false),
                SizedBox(height: 5.h),
                Text(
                  'Surah ${surah.nameEnglish}',
                  style: AppTypography.titleMedium.copyWith(
                    color: Colors.white,
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ).slideIn(
                  RevealDirection.start,
                  delay: const Duration(milliseconds: 70),
                  fade: false,
                ),
                SizedBox(height: 14.h),
                ElevatedButton(
                  onPressed: onContinue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.emeraldInk,
                    foregroundColor: AppColors.onEmeraldInk,
                    padding: EdgeInsets.symmetric(
                      horizontal: 20.w,
                      vertical: 10.h,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                  ),
                  child: Text(
                    'Continue Reading',
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ).slideIn(
                  RevealDirection.bottomStart,
                  delay: const Duration(milliseconds: 140),
                  fade: false,
                  distance: 16,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
