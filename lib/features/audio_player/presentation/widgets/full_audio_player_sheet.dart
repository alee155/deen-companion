import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';

class FullAudioPlayerSheet extends StatelessWidget {
  final String surahNameArabic;
  final String surahNameEnglish;
  final String reciterName;
  final int currentAyah;
  final int totalAyahs;
  final bool isPlaying;
  final double progress; // 0.0–1.0
  final String elapsedLabel;
  final String durationLabel;
  final VoidCallback onPlayPause;
  final VoidCallback onSkipNext;
  final VoidCallback onSkipPrevious;
  final VoidCallback onSleepTimer;
  final VoidCallback onRepeat;
  final VoidCallback onClose;

  const FullAudioPlayerSheet({
    super.key,
    required this.surahNameArabic,
    required this.surahNameEnglish,
    required this.reciterName,
    required this.currentAyah,
    required this.totalAyahs,
    required this.isPlaying,
    required this.progress,
    required this.elapsedLabel,
    required this.durationLabel,
    required this.onPlayPause,
    required this.onSkipNext,
    required this.onSkipPrevious,
    required this.onSleepTimer,
    required this.onRepeat,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.emeraldInk,
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.w),
          child: Column(
            children: [
              SizedBox(height: 8.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: onClose,
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      color: const Color(0xFFC9D6CF),
                      size: 24.sp,
                    ),
                  ),
                  Text(
                    'NOW PLAYING',
                    style: AppTypography.caption.copyWith(
                      color: const Color(0xFF8FA89D),
                      letterSpacing: 1,
                    ),
                  ),
                  Icon(
                    Icons.more_horiz,
                    color: const Color(0xFFC9D6CF),
                    size: 20.sp,
                  ),
                ],
              ),
              SizedBox(height: 40.h),
              Container(
                width: 150.w,
                height: 150.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.gold, width: 1.5),
                ),
                child: Center(
                  child: Container(
                    width: 120.w,
                    height: 120.w,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.gold.withOpacity(0.1),
                    ),
                    child: Center(
                      child: Text(
                        surahNameArabic,
                        textDirection: TextDirection.rtl,
                        style: AppTypography.arabicBody.copyWith(
                          fontSize: 36.sp,
                          color: AppColors.gold,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 24.h),
              Text(
                surahNameEnglish,
                style: AppTypography.greetingSerif.copyWith(
                  color: AppColors.parchment,
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                '$reciterName · Ayah $currentAyah of $totalAyahs',
                style: AppTypography.bodyMedium.copyWith(
                  color: const Color(0xFF8FA89D),
                ),
              ),
              SizedBox(height: 28.h),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    height: 3.h,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(2.r),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: progress.clamp(0.0, 1.0),
                    child: Container(
                      height: 3.h,
                      decoration: BoxDecoration(
                        color: AppColors.gold,
                        borderRadius: BorderRadius.circular(2.r),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 6.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    elapsedLabel,
                    style: AppTypography.caption.copyWith(
                      color: const Color(0xFF8FA89D),
                    ),
                  ),
                  Text(
                    durationLabel,
                    style: AppTypography.caption.copyWith(
                      color: const Color(0xFF8FA89D),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 20.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: onRepeat,
                    child: Icon(
                      Icons.repeat,
                      color: const Color(0xFF8FA89D),
                      size: 18.sp,
                    ),
                  ),
                  GestureDetector(
                    onTap: onSkipPrevious,
                    child: Icon(
                      Icons.skip_previous,
                      color: AppColors.parchment,
                      size: 24.sp,
                    ),
                  ),
                  GestureDetector(
                    onTap: onPlayPause,
                    child: Container(
                      width: 56.w,
                      height: 56.w,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.gold,
                      ),
                      child: Icon(
                        isPlaying ? Icons.pause : Icons.play_arrow,
                        color: AppColors.emeraldInk,
                        size: 26.sp,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: onSkipNext,
                    child: Icon(
                      Icons.skip_next,
                      color: AppColors.parchment,
                      size: 24.sp,
                    ),
                  ),
                  GestureDetector(
                    onTap: onSleepTimer,
                    child: Icon(
                      Icons.bedtime_outlined,
                      color: const Color(0xFF8FA89D),
                      size: 18.sp,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 24.h),
            ],
          ),
        ),
      ),
    );
  }
}
