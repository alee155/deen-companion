import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/entities/dua.dart';

class DuaCardTile extends StatefulWidget {
  final Dua dua;
  const DuaCardTile({super.key, required this.dua});

  @override
  State<DuaCardTile> createState() => _DuaCardTileState();
}

class _DuaCardTileState extends State<DuaCardTile> {
  int _count = 0;

  void _tap() {
    setState(() => _count = _count >= widget.dua.repeat ? 0 : _count + 1);
  }

  @override
  Widget build(BuildContext context) {
    final showCounter = widget.dua.repeat > 1;
    final isComplete = _count >= widget.dua.repeat;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20.w, vertical: 6.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.borderWarm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.dua.title,
            style: AppTypography.titleMedium.copyWith(color: AppColors.inkText),
          ),
          SizedBox(height: 10.h),
          Text(
            widget.dua.arabic,
            textAlign: TextAlign.right,
            textDirection: TextDirection.rtl,
            style: AppTypography.arabicBody.copyWith(
              fontSize: 20.sp,
              color: AppColors.inkText,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            widget.dua.transliteration,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.duasAccent,
              fontStyle: FontStyle.italic,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            widget.dua.translation,
            style: AppTypography.bodyLarge.copyWith(color: AppColors.inkText),
          ),
          SizedBox(height: 10.h),
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.dua.source,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              ),
              if (showCounter)
                GestureDetector(
                  onTap: _tap,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 10.w,
                      vertical: 5.h,
                    ),
                    decoration: BoxDecoration(
                      color: isComplete
                          ? AppColors.emeraldInk
                          : AppColors.duasAccentBg,
                      borderRadius: BorderRadius.circular(20.r),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isComplete ? Icons.check : Icons.touch_app_outlined,
                          size: 13.sp,
                          color: isComplete
                              ? AppColors.parchment
                              : AppColors.duasAccent,
                        ),
                        SizedBox(width: 5.w),
                        Text(
                          '$_count/${widget.dua.repeat}',
                          style: AppTypography.caption.copyWith(
                            color: isComplete
                                ? AppColors.parchment
                                : AppColors.duasAccent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
