import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/motion/motion.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/bayan_video.dart';
import '../video_labels.dart';
import 'video_thumbnail.dart';

/// A video in a list: a small picture beside the title, speaker and topic.
class VideoTile extends StatelessWidget {
  final BayanVideo video;
  final VoidCallback onTap;
  const VideoTile({super.key, required this.video, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final duration = video.duration;
    return Semantics(
      button: true,
      label: 'Play ${video.title}, ${video.speaker}',
      excludeSemantics: true,
      child: Pressable(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.all(10.w),
          decoration: BoxDecoration(
            color: AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(20.r),
            border: Border.all(color: AppColors.borderWarm),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14.r),
                child: SizedBox(
                  width: 124.w,
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        VideoThumbnail(url: video.thumbnail),
                        Center(
                          child: Container(
                            width: 28.w,
                            height: 28.w,
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.5),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.play_arrow_rounded,
                              size: 18.sp,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        if (duration != null)
                          Positioned(
                            right: 4.w,
                            bottom: 4.h,
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 5.w,
                                vertical: 1.h,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.65),
                                borderRadius: BorderRadius.circular(5.r),
                              ),
                              child: Text(
                                formatVideoDuration(duration),
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 9.5.sp,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
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
                    SizedBox(height: 3.h),
                    Text(
                      video.speaker,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    if (video.category.isNotEmpty) ...[
                      SizedBox(height: 6.h),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8.w,
                          vertical: 2.h,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.worshipAccentBg,
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                        child: Text(
                          video.category,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10.5.sp,
                            fontWeight: FontWeight.w700,
                            color: AppColors.worshipAccent,
                          ),
                        ),
                      ),
                    ],
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
