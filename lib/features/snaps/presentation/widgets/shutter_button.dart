import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';

/// Our own shutter: a gold ring around a warm disc that presses in. While a
/// photo is being taken the ring spins.
class ShutterButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final bool busy;

  const ShutterButton({super.key, required this.onPressed, this.busy = false});

  @override
  State<ShutterButton> createState() => _ShutterButtonState();
}

class _ShutterButtonState extends State<ShutterButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null && !widget.busy;
    final outer = 80.w;
    return Semantics(
      button: true,
      enabled: enabled,
      label: 'Take photo',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => setState(() => _down = true) : null,
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (_) => setState(() => _down = false),
        onTap: enabled
            ? () {
                HapticFeedback.mediumImpact();
                widget.onPressed!();
              }
            : null,
        child: SizedBox(
          width: outer,
          height: outer,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: outer,
                height: outer,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.emeraldInk.withValues(
                      alpha: enabled || widget.busy ? 1 : 0.4,
                    ),
                    width: 4,
                  ),
                ),
              ),
              if (widget.busy)
                SizedBox(
                  width: outer,
                  height: outer,
                  child: CircularProgressIndicator(
                    strokeWidth: 4,
                    color: AppColors.emeraldInk,
                  ),
                ),
              AnimatedScale(
                scale: _down ? 0.82 : 1,
                duration: const Duration(milliseconds: 90),
                curve: Curves.easeOut,
                child: Container(
                  width: outer - 20.w,
                  height: outer - 20.w,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.emeraldInk, AppColors.emeraldInkDark],
                    ),
                  ),
                  child: Icon(
                    Icons.mosque_rounded,
                    size: 26.sp,
                    color: AppColors.onEmeraldInk.withValues(alpha: 0.8),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
