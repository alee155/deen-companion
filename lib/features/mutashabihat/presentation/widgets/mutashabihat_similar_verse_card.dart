import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/mutashabihat_verse_ref.dart';

class MutashabihatSimilarVerseCard extends StatefulWidget {
  final MutashabihatVerseRef verse;
  final bool startHidden;

  const MutashabihatSimilarVerseCard({
    super.key,
    required this.verse,
    required this.startHidden,
  });

  @override
  State<MutashabihatSimilarVerseCard> createState() =>
      _MutashabihatSimilarVerseCardState();
}

class _MutashabihatSimilarVerseCardState
    extends State<MutashabihatSimilarVerseCard> {
  late bool _hidden;

  @override
  void initState() {
    super.initState();
    _hidden = widget.startHidden;
  }

  @override
  void didUpdateWidget(covariant MutashabihatSimilarVerseCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.startHidden != widget.startHidden)
      _hidden = widget.startHidden;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(top: 12.h),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: AppColors.borderWarm),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Padding(
            padding: EdgeInsets.all(16.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${widget.verse.surahNameEnglish} ${widget.verse.verseKey}',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  widget.verse.arabic,
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    fontSize: 18.sp,
                    color: AppColors.inkText,
                    height: 1.9,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  widget.verse.translation,
                  style: TextStyle(fontSize: 13.sp, color: AppColors.inkText),
                ),
              ],
            ),
          ),
          if (_hidden)
            Positioned.fill(
              child: GestureDetector(
                onTap: () => setState(() => _hidden = false),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: Container(
                    color: AppColors.surfaceLight.withOpacity(0.55),
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.visibility_outlined,
                          color: AppColors.quranAccent,
                          size: 20.sp,
                        ),
                        SizedBox(height: 6.h),
                        Text(
                          'Tap to compare',
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: AppColors.quranAccent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
