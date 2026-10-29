import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/motion/motion.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/bayan_video.dart';
import '../video_labels.dart';
import 'video_thumbnail.dart';

/// A video on Home: its picture with a play button, then the title and who is
/// speaking. The duration shows only when the API knows it.
class VideoCard extends StatelessWidget {
  /// The card's width; its picture is 16:9 of this.
  static double get width => 250.w;

  final BayanVideo video;
  final VoidCallback onTap;
  final bool isLast;

  const VideoCard({
    super.key,
    required this.video,
    required this.onTap,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final duration = video.duration;
    return Semantics(
      button: true,
      label: 'Play ${video.title}, ${video.speaker}',
      excludeSemantics: true,
      child: Pressable(
        onTap: onTap,
        haptic: true,
        child: Container(
          width: width,
          margin: EdgeInsets.only(right: isLast ? 0 : 12.w),
          decoration: BoxDecoration(
            color: AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(20.r),
            border: Border.all(color: AppColors.borderWarm),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadow,
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    VideoThumbnail(url: video.thumbnail),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.02),
                            Colors.black.withValues(alpha: 0.45),
                          ],
                        ),
                      ),
                    ),
                    if (video.category.isNotEmpty)
                      Positioned(
                        top: 8.h,
                        left: 8.w,
                        right: 56.w,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: _Badge(video.category),
                        ),
                      ),
                    if (duration != null)
                      Positioned(
                        top: 8.h,
                        right: 8.w,
                        child: _Badge(formatVideoDuration(duration)),
                      ),
                    Positioned(
                      right: 10.w,
                      bottom: 8.h,
                      child: Container(
                        width: 38.w,
                        height: 38.w,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.92),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.play_arrow_rounded,
                          size: 22.sp,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(12.w, 10.h, 12.w, 12.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      video.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5.sp,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                        color: AppColors.inkText,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      video.speaker,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  const _Badge(this.text);

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(8.r),
    ),
    child: Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: Colors.white,
        fontSize: 10.5.sp,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}
