import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';

/// Frosted round button for the dark camera/editor surfaces.
class SnapRoundButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String tooltip;
  final bool active;
  final double size;

  const SnapRoundButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    this.active = false,
    this.size = 44,
  });

  @override
  Widget build(BuildContext context) {
    final box = size.w;
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        child: InkResponse(
          onTap: onPressed,
          radius: box * 0.7,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: box,
            height: box,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active
                  ? AppColors.emeraldInk.withValues(alpha: 0.9)
                  : Colors.white.withValues(
                      alpha: onPressed == null ? 0.06 : 0.14,
                    ),
              border: Border.all(
                color: active
                    ? AppColors.emeraldInk
                    : Colors.white.withValues(alpha: 0.2),
              ),
            ),
            child: Icon(
              icon,
              size: box * 0.5,
              color: active
                  ? AppColors.onEmeraldInk
                  : Colors.white.withValues(alpha: onPressed == null ? 0.4 : 1),
            ),
          ),
        ),
      ),
    );
  }
}

/// Dark gradient behind every capture/edit step.
class SnapBackdrop extends StatelessWidget {
  final Widget child;
  const SnapBackdrop({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(AppColors.heroSurface, Colors.black, 0.55)!,
            Colors.black,
          ],
        ),
      ),
      child: child,
    );
  }
}

/// Small pill used for labels over the image / preview.
class SnapPill extends StatelessWidget {
  final IconData? icon;
  final String text;
  final bool gold;

  const SnapPill({super.key, required this.text, this.icon, this.gold = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
      decoration: BoxDecoration(
        color: gold
            ? AppColors.emeraldInk.withValues(alpha: 0.9)
            : Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(
          color: gold
              ? AppColors.emeraldInk
              : Colors.white.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 13.sp,
              color: gold ? AppColors.onEmeraldInk : AppColors.emeraldInk,
            ),
            SizedBox(width: 5.w),
          ],
          Text(
            text,
            style: TextStyle(
              fontSize: 11.5.sp,
              fontWeight: FontWeight.w700,
              color: gold ? AppColors.onEmeraldInk : Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
