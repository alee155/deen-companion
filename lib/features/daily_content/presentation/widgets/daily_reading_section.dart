import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';

/// One reading block (Ayat or Hadith) as a 22px bordered surface — same
/// card language as Groups and Explore. Header carries the Explore icon,
/// title and source line; then the Arabic on a softly tinted panel, then the
/// translation beside an accent rule.
class DailyReadingSection extends StatelessWidget {
  final String iconAsset;
  final String title;
  final String source;
  final String? arabic;
  final String translation;

  /// Small pill after the translation (e.g. a hadith's grade).
  final String? badge;
  final VoidCallback onShare;

  const DailyReadingSection({
    super.key,
    required this.iconAsset,
    required this.title,
    required this.source,
    required this.translation,
    required this.onShare,
    this.arabic,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final hasArabic = arabic != null && arabic!.trim().isNotEmpty;
    final hasTranslation = translation.trim().isNotEmpty;

    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(22.r),
        border: Border.all(color: AppColors.borderWarm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 46.w,
                height: 46.w,
                padding: EdgeInsets.all(10.w),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(15.r),
                  border: Border.all(color: AppColors.borderWarm, width: 1.2.w),
                ),
                child: Image.asset(iconAsset, fit: BoxFit.contain),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w700,
                        color: AppColors.inkText,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      source,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5.sp,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              InkResponse(
                onTap: onShare,
                radius: 22.r,
                child: Container(
                  width: 36.w,
                  height: 36.w,
                  decoration: BoxDecoration(
                    color: AppColors.worshipAccentBg,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.ios_share_rounded,
                    size: 17.sp,
                    color: AppColors.worshipAccent,
                  ),
                ),
              ),
            ],
          ),
          if (hasArabic) ...[
            SizedBox(height: 14.h),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 16.h),
              decoration: BoxDecoration(
                color: AppColors.worshipAccentBg,
                borderRadius: BorderRadius.circular(18.r),
              ),
              child: SizedBox(
                width: double.infinity,
                child: Text(
                  arabic!.trim(),
                  textAlign: TextAlign.center,
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    fontFamily: 'AmiriQuran',
                    fontSize: 24.sp,
                    height: 2.0,
                    color: AppColors.inkText,
                  ),
                ),
              ),
            ),
          ],
          SizedBox(height: 14.h),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 3.w,
                  decoration: BoxDecoration(
                    color: AppColors.emeraldInk,
                    borderRadius: BorderRadius.circular(3.r),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Text(
                    hasTranslation
                        ? translation.trim()
                        : 'No English translation is available for this entry.',
                    style: AppTypography.bodyLarge.copyWith(
                      height: 1.7,
                      color: hasTranslation
                          ? AppColors.inkText
                          : AppColors.textMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (badge != null && badge!.isNotEmpty) ...[
            SizedBox(height: 12.h),
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: AppColors.worshipAccentBg,
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Text(
                  badge!,
                  style: TextStyle(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w800,
                    color: AppColors.worshipAccent,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
