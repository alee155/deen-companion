import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_colors.dart';

/// The "send a snap" button: a round green button with a white camera and a
/// soft green glow around it. There is no label; the tooltip and the
/// accessibility label say "Send snap".
///
/// It is always shown. When a snap can't be sent right now ([available] is
/// false) it turns grey and loses its glow, but stays tappable: [onPressed]
/// still runs so the caller can say *why* (a toast), instead of the button
/// silently doing nothing.
class SendSnapButton extends StatelessWidget {
  final VoidCallback onPressed;

  /// False greys the button out. It is still tappable, see above.
  final bool available;

  /// Diameter of the circle, before screen scaling.
  final double size;

  const SendSnapButton({
    super.key,
    required this.onPressed,
    this.available = true,
    this.size = 62,
  });

  static const _fade = Duration(milliseconds: 260);

  @override
  Widget build(BuildContext context) {
    final diameter = size.w;
    final fill = available
        ? AppColors.emeraldInk
        : Color.lerp(AppColors.textMuted, AppColors.parchment, 0.35)!;
    final glow = AppColors.emeraldInk;
    final label = available ? 'Send snap' : 'Send snap, unavailable right now';

    return Semantics(
      button: true,
      label: label,
      hint: available ? null : 'Double tap to hear why',
      child: Tooltip(
        message: available ? 'Send snap' : 'Snap unavailable right now',
        child: AnimatedContainer(
          duration: _fade,
          width: diameter,
          height: diameter,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: available
                ? [
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
                  ]
                : [
                    // Disabled: a plain, quiet shadow, no glow.
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
          ),
          child: Material(
            color: fill,
            animationDuration: _fade,
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
                  color: Colors.white.withValues(alpha: available ? 1 : 0.9),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
