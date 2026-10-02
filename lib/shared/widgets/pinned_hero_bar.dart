import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../core/theme/app_colors.dart';
import 'islamic_ornaments.dart';

/// Pinned bar that floats over a dark hero and solidifies (with a title)
/// as the page scrolls.
class PinnedHeroBar extends StatelessWidget {
  final ValueListenable<double> opacity;
  final String title;
  final IconData? trailingIcon;
  final String? trailingTooltip;
  final VoidCallback? onTrailing;

  /// False for tab roots, which have nothing to go back to.
  final bool showBack;

  const PinnedHeroBar({
    super.key,
    required this.opacity,
    required this.title,
    this.trailingIcon,
    this.trailingTooltip,
    this.onTrailing,
    this.showBack = true,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: opacity,
      builder: (context, raw, _) {
        // Solidify quickly so content never shows through behind the buttons.
        final t = (raw * 2.5).clamp(0.0, 1.0);
        return Container(
          decoration: BoxDecoration(
            color: AppColors.heroSurface.withValues(alpha: t),
            boxShadow: t > 0.6
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18 * t),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 8.h),
              child: Row(
                children: [
                  if (showBack)
                    GlassIconButton(
                      icon: Icons.arrow_back_rounded,
                      tooltip: 'Back',
                      strength: t,
                      onPressed: () => Navigator.of(context).maybePop(),
                    )
                  else
                    SizedBox(width: 40.w),
                  Expanded(
                    child: Opacity(
                      opacity: t,
                      child: Text(
                        title,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 17.sp,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  if (trailingIcon != null)
                    GlassIconButton(
                      icon: trailingIcon!,
                      strength: t,
                      tooltip: trailingTooltip,
                      onPressed: onTrailing ?? () {},
                    )
                  else
                    SizedBox(width: 40.w),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
