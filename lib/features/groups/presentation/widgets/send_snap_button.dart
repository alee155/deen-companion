import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_colors.dart';

/// The group's "send a snap" button: a round green button with a white camera
/// and a soft green glow around it. There is no label; the tooltip and the
/// accessibility label say "Send snap".
class SendSnapButton extends StatelessWidget {
  final VoidCallback onPressed;

  /// Diameter of the circle, before screen scaling.
  final double size;

  const SendSnapButton({super.key, required this.onPressed, this.size = 62});

  @override
  Widget build(BuildContext context) {
    final diameter = size.w;
    final glow = AppColors.emeraldInk;
    return Semantics(
      button: true,
      label: 'Send snap',
      child: Tooltip(
        message: 'Send snap',
        child: Container(
          width: diameter,
          height: diameter,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              // Tight, bright halo…
              BoxShadow(
                color: glow.withValues(alpha: 0.55),
                blurRadius: 20,
                spreadRadius: 1,
              ),
              // …and a wide, soft one.
              BoxShadow(
                color: glow.withValues(alpha: 0.28),
                blurRadius: 42,
                spreadRadius: 6,
              ),
            ],
          ),
          child: Material(
            color: glow,
            shape: CircleBorder(
              side: BorderSide(color: Colors.white.withValues(alpha: 0.35)),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onPressed,
              child: Center(
                child: Icon(
                  Icons.camera_alt_rounded,
                  size: 28.sp,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
