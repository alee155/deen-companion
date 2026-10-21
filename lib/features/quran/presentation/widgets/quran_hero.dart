import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/motion/motion.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/islamic_ornaments.dart';

/// Hero header shared by the Quran screens: gradient, geometric pattern,
/// Arabic title, glass buttons and an optional wide chip below.
class QuranHero extends StatelessWidget {
  final String arabicTitle;
  final String subtitle;
  final IconData? actionIcon;
  final String? actionTooltip;
  final VoidCallback? onAction;
  final IconData? chipIcon;
  final String? chipLabel;
  final VoidCallback? onChip;

  /// Optional row of (value, label) stat tiles under the title.
  final List<(String, String)> stats;

  /// Replaces the single action button with several (e.g. in the reader).
  final List<Widget> actions;

  /// 0..1 reading progress drawn as a gold rule along the header's bottom.
  final double? progress;

  /// Optional artwork (e.g. a book cover) shown behind the header.
  final String? backgroundAsset;

  const QuranHero({
    super.key,
    required this.arabicTitle,
    required this.subtitle,
    this.actionIcon,
    this.actionTooltip,
    this.onAction,
    this.chipIcon,
    this.chipLabel,
    this.onChip,
    this.stats = const [],
    this.actions = const [],
    this.progress,
    this.backgroundAsset,
  });

  Widget _stat(String value, String label) => Container(
    padding: EdgeInsets.symmetric(vertical: 10.h),
    decoration: BoxDecoration(
      color: AppColors.onHeroSurface.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(16.r),
      border: Border.all(
        color: AppColors.onHeroSurface.withValues(alpha: 0.12),
      ),
    ),
    child: Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.w800,
            color: AppColors.goldLight,
          ),
        ),
        SizedBox(height: 2.h),
        Text(
          label,
          style: TextStyle(
            fontSize: 11.sp,
            color: AppColors.onHeroSurface.withValues(alpha: 0.75),
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final seq = RevealSequence();
    final hasChip = chipLabel != null && onChip != null;
    final hasAction = actionIcon != null && onAction != null;

    Widget stat(IconData icon, String label, VoidCallback onTap) => Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 11.h),
          decoration: BoxDecoration(
            color: AppColors.onHeroSurface.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(
              color: AppColors.onHeroSurface.withValues(alpha: 0.12),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 17.sp, color: AppColors.goldLight),
              SizedBox(width: 8.w),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onHeroSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: AppColors.heroGradient,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(30.r)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          if (backgroundAsset != null) ...[
            Positioned.fill(
              child: Image.asset(
                backgroundAsset!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.55),
                      Colors.black.withValues(alpha: 0.72),
                    ],
                  ),
                ),
              ),
            ),
          ],
          Positioned.fill(
            child: GeometricPattern(
              color: AppColors.goldLight.withValues(alpha: 0.08),
              cell: 50,
            ),
          ),
          if (progress != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                height: 3.h,
                alignment: Alignment.centerLeft,
                color: AppColors.onHeroSurface.withValues(alpha: 0.12),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(end: progress!.clamp(0.0, 1.0)),
                  duration: const Duration(milliseconds: 160),
                  builder: (_, v, _) => FractionallySizedBox(
                    widthFactor: v,
                    child: Container(color: AppColors.gold),
                  ),
                ),
              ),
            ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 18.h),
              child: Column(
                children: [
                  Row(
                    children: [
                      GlassIconButton(
                        icon: Icons.arrow_back_rounded,
                        tooltip: 'Back',
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              arabicTitle,
                              textDirection: TextDirection.rtl,
                              style: TextStyle(
                                fontFamily: 'AmiriQuran',
                                fontSize: 26.sp,
                                color: AppColors.goldLight,
                                height: 1.3,
                              ),
                            ).slideIn(RevealDirection.top, delay: seq.next()),
                            Text(
                              subtitle,
                              style: TextStyle(
                                fontSize: 11.sp,
                                letterSpacing: 0.5,
                                color: AppColors.onHeroSurface.withValues(
                                  alpha: 0.7,
                                ),
                              ),
                            ).slideIn(
                              RevealDirection.bottom,
                              delay: seq.next(),
                            ),
                          ],
                        ),
                      ),
                      if (actions.isNotEmpty)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (var i = 0; i < actions.length; i++) ...[
                              if (i > 0) SizedBox(width: 8.w),
                              actions[i],
                            ],
                          ],
                        )
                      else if (hasAction)
                        GlassIconButton(
                          icon: actionIcon!,
                          tooltip: actionTooltip ?? '',
                          onPressed: onAction!,
                        )
                      else
                        SizedBox(width: 40.w),
                    ],
                  ),
                  if (stats.isNotEmpty) ...[
                    SizedBox(height: 16.h),
                    Row(
                      children: [
                        for (var i = 0; i < stats.length; i++) ...[
                          if (i > 0) SizedBox(width: 10.w),
                          Expanded(child: _stat(stats[i].$1, stats[i].$2)),
                        ],
                      ],
                    ).slideIn(
                      RevealDirection.bottom,
                      delay: seq.next(),
                      distance: 18,
                    ),
                  ],
                  if (hasChip) ...[
                    SizedBox(height: 16.h),
                    Row(
                      children: [stat(chipIcon!, chipLabel!, onChip!)],
                    ).slideIn(
                      RevealDirection.bottom,
                      delay: seq.next(),
                      distance: 18,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
