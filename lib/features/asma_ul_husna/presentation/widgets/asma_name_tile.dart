import 'package:flutter/material.dart';
import 'package:deen_companion/core/motion/motion.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/asma_name.dart';
import 'asma_ornaments.dart';

/// Grid card for a single Name: tinted tile, star number badge, Arabic
/// calligraphy and transliteration. Sized for a 3-column grid.
class AsmaNameTile extends StatelessWidget {
  final AsmaName name;
  final VoidCallback onTap;

  const AsmaNameTile({super.key, required this.name, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final tint = AsmaTint.of(name.number);
    return PressScale(
      child: Material(
        color: tint.bg,
        borderRadius: BorderRadius.circular(20.r),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          splashColor: tint.accent.withValues(alpha: 0.12),
          highlightColor: tint.accent.withValues(alpha: 0.06),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20.r),
              border: Border.all(color: tint.accent.withValues(alpha: 0.18)),
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: GeometricPattern(
                    color: tint.accent.withValues(alpha: 0.07),
                    cell: 30,
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(10.w, 10.h, 10.w, 10.h),
                  child: Column(
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: StarBadge(
                          label: '${name.number}',
                          size: 26.w,
                          fill: tint.accent.withValues(alpha: 0.16),
                          stroke: tint.accent.withValues(alpha: 0.5),
                          textColor: tint.accent,
                        ),
                      ),
                      Expanded(
                        child: Center(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              name.arabic,
                              textDirection: TextDirection.rtl,
                              maxLines: 1,
                              style: TextStyle(
                                fontFamily: kAsmaArabicFont,
                                fontSize: 26.sp,
                                color: AppColors.inkText,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Text(
                        name.transliteration,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w600,
                          color: tint.accent,
                        ),
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

/// Roomier list-mode row for a single Name.
class AsmaNameRow extends StatelessWidget {
  final AsmaName name;
  final VoidCallback onTap;

  const AsmaNameRow({super.key, required this.name, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final tint = AsmaTint.of(name.number);
    return PressScale(
      child: Material(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(18.r),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18.r),
              border: Border.all(color: AppColors.borderWarm),
            ),
            child: Row(
              children: [
                StarBadge(
                  label: '${name.number}',
                  size: 38.w,
                  fill: tint.bg,
                  stroke: tint.accent.withValues(alpha: 0.55),
                  textColor: tint.accent,
                ),
                SizedBox(width: 14.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name.transliteration,
                        style: TextStyle(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w700,
                          color: AppColors.inkText,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        name.english,
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
                SizedBox(width: 10.w),
                Text(
                  name.arabic,
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    fontFamily: kAsmaArabicFont,
                    fontSize: 26.sp,
                    color: AppColors.inkText,
                    height: 1.4,
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
