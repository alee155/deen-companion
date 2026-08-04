import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/entities/hadith_collection.dart';
import '../../domain/hadith_cover_assets.dart';
import '../../domain/hadith_grade.dart';

/// A collection presented as a book on a shelf: spine-lit cover, the Arabic
/// title in gold across it, then the compiler and the size of the collection
/// underneath.
///
/// The point of the layout is identity — you should recognise Bukhari from
/// Muslim at a glance, and the small collections (40 Hadith Nawawi and friends)
/// should look deliberately different rather than like missing data.
class HadithBookCard extends StatelessWidget {
  final HadithCollection collection;
  final VoidCallback onTap;

  const HadithBookCard({
    super.key,
    required this.collection,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceLight,
      borderRadius: BorderRadius.circular(20.r),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20.r),
            border: Border.all(color: AppColors.borderWarm),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Hero(
                  tag: 'hadith-cover-${collection.key}',
                  child: _Cover(collection: collection),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(12.w, 10.h, 12.w, 12.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      collection.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.headline.copyWith(
                        fontSize: 13.5.sp,
                        height: 1.25,
                        color: AppColors.inkText,
                      ),
                    ),
                    SizedBox(height: 3.h),
                    Text(
                      collection.author,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Row(
                      children: [
                        Expanded(
                          child: _CountChip(total: collection.totalHadiths),
                        ),
                        SizedBox(width: 6.w),
                        _ReliabilityDot(reliability: collection.reliability),
                      ],
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

class _Cover extends StatelessWidget {
  final HadithCollection collection;
  const _Cover({required this.collection});

  @override
  Widget build(BuildContext context) {
    final asset = HadithCoverAssets.forKey(collection.key);

    return Stack(
      fit: StackFit.expand,
      children: [
        if (asset != null)
          Image.asset(
            asset,
            fit: BoxFit.cover,
            // A bundle/decode failure falls back to the drawn cover rather
            // than Flutter's grey error box.
            errorBuilder: (context, error, stack) =>
                _FallbackCover(collection: collection),
          )
        else
          _FallbackCover(collection: collection),

        // Scrim: dark at the foot so the gold Arabic title always has contrast,
        // whatever the artwork underneath is doing.
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: [0.35, 1.0],
              colors: [Colors.transparent, Color(0xCC0B1210)],
            ),
          ),
        ),

        // Spine highlight down the left edge — the detail that makes it read
        // as a book rather than a photo.
        Align(
          alignment: Alignment.centerLeft,
          child: Container(
            width: 3.w,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.gold.withValues(alpha: 0.0),
                  AppColors.gold.withValues(alpha: 0.55),
                  AppColors.gold.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ),

        Positioned(
          left: 10.w,
          right: 10.w,
          bottom: 8.h,
          child: Text(
            collection.arabicName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.right,
            style: AppTypography.arabicBody.copyWith(
              fontSize: 15.sp,
              height: 1.4,
              color: const Color(0xFFF0DFB4),
            ),
          ),
        ),
      ],
    );
  }
}

/// Drawn cover for collections with no artwork: a deep teal field, a corner
/// ornament, and the hadith count set large — so the 40-hadith collections
/// look like a designed edition instead of a gap.
class _FallbackCover extends StatelessWidget {
  final HadithCollection collection;
  const _FallbackCover({required this.collection});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.heroSurface, AppColors.emeraldInkDark],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            top: -18.h,
            right: -18.w,
            child: Icon(
              Icons.brightness_7_rounded,
              size: 96.sp,
              color: AppColors.gold.withValues(alpha: 0.14),
            ),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.auto_stories_rounded,
                  size: 26.sp,
                  color: AppColors.gold.withValues(alpha: 0.9),
                ),
                SizedBox(height: 8.h),
                Text(
                  '${collection.totalHadiths}',
                  style: AppTypography.heroSerif.copyWith(
                    fontSize: 26.sp,
                    color: const Color(0xFFF0DFB4),
                  ),
                ),
                Text(
                  'HADITH',
                  style: AppTypography.caption.copyWith(
                    letterSpacing: 2,
                    color: AppColors.gold.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CountChip extends StatelessWidget {
  final int total;
  const _CountChip({required this.total});

  /// 7580 → "7,580". Reads far faster at a glance than a bare digit run.
  String get _formatted {
    final digits = total.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: AppColors.hadithAccentBg,
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Text(
        '$_formatted hadith',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTypography.caption.copyWith(
          color: AppColors.hadithAccent,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// The collection's overall grading, as a single dot with a tooltip — the full
/// wording ("Hasan/Sahih") would crowd the card at this size.
class _ReliabilityDot extends StatelessWidget {
  final String reliability;
  const _ReliabilityDot({required this.reliability});

  @override
  Widget build(BuildContext context) {
    final grade = HadithGrade.parse(reliability);
    final color = switch (grade) {
      HadithGrade.sahih => AppColors.success,
      HadithGrade.hasan => AppColors.duasAccent,
      HadithGrade.daif => AppColors.error,
      HadithGrade.unknown => AppColors.textMuted,
    };

    return Tooltip(
      message: reliability.trim().isEmpty
          ? 'Grading varies'
          : 'Grading: ${reliability.trim()}',
      child: Container(
        width: 10.w,
        height: 10.w,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.9),
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.surfaceLight, width: 1.5),
        ),
      ),
    );
  }
}
