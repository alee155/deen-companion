import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/motion/motion.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../shared/widgets/translation_unavailable.dart';
import '../../../../shared/widgets/urdu_aware_text.dart';
import '../../domain/entities/asma_name.dart';
import 'asma_ornaments.dart';

/// One Name as a reading card, the way the Ayat & Hadith of the Day screen sets
/// out a reading: a bordered surface with a header (number, the Name, actions),
/// the Arabic on a tinted panel, then the meaning beside an accent rule.
class AsmaNameCard extends StatelessWidget {
  final AsmaName name;

  /// Buttons at the end of the header (favourite, share, copy).
  final List<Widget> actions;

  /// Hide the meaning (a screen that gives it room of its own).
  final bool showMeaning;

  const AsmaNameCard({
    super.key,
    required this.name,
    this.actions = const [],
    this.showMeaning = true,
  });

  @override
  Widget build(BuildContext context) {
    final tint = AsmaTint.of(name.number);
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
              StarBadge(
                label: '${name.number}',
                size: 40.w,
                fill: tint.bg,
                stroke: tint.accent.withValues(alpha: 0.55),
                textColor: tint.accent,
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name.transliteration,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w700,
                        color: AppColors.inkText,
                      ),
                    ),
                    SizedBox(height: 1.h),
                    UrduAwareText(
                      name.english,
                      urdu: name.urdu,
                      maxLines: 2,
                      urduHeight: 1.8,
                      style: TextStyle(
                        fontSize: 12.5.sp,
                        fontWeight: FontWeight.w600,
                        color: tint.accent,
                      ),
                    ),
                  ],
                ),
              ),
              for (final a in actions) ...[SizedBox(width: 6.w), a],
            ],
          ),
          SizedBox(height: 14.h),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 22.h),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: tint.bg,
              borderRadius: BorderRadius.circular(18.r),
              border: Border.all(color: tint.accent.withValues(alpha: 0.18)),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: GeometricPattern(
                    color: tint.accent.withValues(alpha: 0.07),
                    cell: 34,
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      name.arabic,
                      textDirection: TextDirection.rtl,
                      maxLines: 1,
                      style: TextStyle(
                        fontFamily: kAsmaArabicFont,
                        fontSize: 48.sp,
                        height: 1.6,
                        color: AppColors.inkText,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (showMeaning) ...[
            SizedBox(height: 14.h),
            _Meaning(name: name, accent: tint.accent),
          ],
        ],
      ),
    );
  }
}

class _Meaning extends StatelessWidget {
  final AsmaName name;
  final Color accent;

  const _Meaning({required this.name, required this.accent});

  @override
  Widget build(BuildContext context) {
    final missing = name.urdu && name.meaning.trim().isEmpty;
    return Container(
      decoration: BoxDecoration(
        border: BorderDirectional(
          start: BorderSide(color: accent.withValues(alpha: 0.5), width: 2.5),
        ),
      ),
      padding: EdgeInsetsDirectional.only(start: 12.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'MEANING',
            style: TextStyle(
              fontSize: 10.5.sp,
              letterSpacing: 1.4,
              fontWeight: FontWeight.w700,
              color: accent,
            ),
          ),
          SizedBox(height: 6.h),
          if (missing)
            TranslationUnavailable(fontSize: 14.sp)
          else
            UrduAwareText(
              name.meaning,
              urdu: name.urdu,
              urduHeight: 2.0,
              style: TextStyle(
                fontSize: 15.sp,
                height: 1.6,
                color: AppColors.inkText,
              ),
            ),
        ],
      ),
    );
  }
}

/// A tap-to-recite counter on a tinted card: a ring that fills as you recite,
/// the target to aim for, and a way back to zero. Used by both the Name's own
/// screen and the daily practice, so reciting feels the same in each.
class AsmaTasbihCard extends StatelessWidget {
  final AsmaTint tint;
  final int count;
  final int target;
  final List<int> targets;

  /// The line above the count, e.g. "Tap to recite".
  final String title;
  final VoidCallback? onTap;
  final ValueChanged<int> onTarget;
  final VoidCallback? onReset;

  const AsmaTasbihCard({
    super.key,
    required this.tint,
    required this.count,
    required this.target,
    required this.targets,
    required this.title,
    required this.onTap,
    required this.onTarget,
    this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final reached = count >= target;
    final progress = (count / target).clamp(0.0, 1.0);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        color: tint.bg,
        borderRadius: BorderRadius.circular(22.r),
        border: Border.all(color: tint.accent.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          Pressable(
            onTap: onTap,
            child: SizedBox(
              width: 108.w,
              height: 108.w,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween<double>(end: progress),
                    duration: context.motion.duration(AppMotion.normal),
                    curve: AppMotion.entrance,
                    builder: (_, v, _) => CustomPaint(
                      size: Size.square(108.w),
                      painter: RingPainter(
                        progress: v,
                        track: tint.accent.withValues(alpha: 0.18),
                        color: reached ? AppColors.gold : tint.accent,
                      ),
                    ),
                  ),
                  BumpOnChange(
                    value: count,
                    child: AnimatedContainer(
                      duration: context.motion.duration(AppMotion.fast),
                      width: 82.w,
                      height: 82.w,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: reached ? AppColors.gold : AppColors.heroSurface,
                      ),
                      alignment: Alignment.center,
                      child: IconSwap(
                        child: reached
                            ? Icon(
                                Icons.check_rounded,
                                key: const ValueKey('done'),
                                size: 36.sp,
                                color: AppColors.heroSurface,
                              )
                            : Text(
                                '$count',
                                key: const ValueKey('count'),
                                style: TextStyle(
                                  fontSize: 28.sp,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.goldLight,
                                ),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedText(
                  title,
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.inkText,
                  ),
                ),
                SizedBox(height: 2.h),
                AnimatedText(
                  '$count of $target',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: AppColors.textSecondary,
                  ),
                ),
                SizedBox(height: 10.h),
                Wrap(
                  spacing: 6.w,
                  runSpacing: 6.h,
                  children: [
                    for (final t in targets)
                      Pressable(
                        scale: AppMotion.pressScaleSmall,
                        onTap: () => onTarget(t),
                        child: AnimatedContainer(
                          duration: AppMotion.fast,
                          padding: EdgeInsets.symmetric(
                            horizontal: 10.w,
                            vertical: 5.h,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12.r),
                            color: t == target
                                ? tint.accent
                                : Colors.transparent,
                            border: Border.all(
                              color: tint.accent.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Text(
                            '$t',
                            style: TextStyle(
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w700,
                              color: t == target
                                  ? AppColors.surfaceLight
                                  : tint.accent,
                            ),
                          ),
                        ),
                      ),
                    if (onReset != null)
                      Pressable(
                        scale: AppMotion.pressScaleSmall,
                        onTap: onReset,
                        child: Padding(
                          padding: EdgeInsets.all(4.w),
                          child: Icon(
                            Icons.restart_alt_rounded,
                            size: 20.sp,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
