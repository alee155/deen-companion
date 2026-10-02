import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/motion/motion.dart';
import '../../../../core/theme/app_colors.dart';

/// Loading/initialising state: concentric rings pulse outward from a compass
/// glyph while a faint sweep rotates, like a radar searching for the Kaaba.
/// Looping is justified here — it conveys live "working" state — and it
/// collapses to a static glyph when motion is reduced.
class QiblaRadar extends StatefulWidget {
  final double size;
  final String label;
  const QiblaRadar({super.key, required this.size, required this.label});

  @override
  State<QiblaRadar> createState() => _QiblaRadarState();
}

class _QiblaRadarState extends State<QiblaRadar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (!context.motion.reduced) _c.repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _c,
            builder: (context, _) => CustomPaint(
              size: Size.square(widget.size),
              painter: _RadarPainter(t: _c.value, color: AppColors.amber),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.explore_rounded,
                size: 44.sp,
                color: AppColors.goldLight,
              ),
              SizedBox(height: 10.h),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 13.sp,
                  color: AppColors.onHeroSurface.withValues(alpha: 0.8),
                ),
              ),
            ],
          ).appear(),
        ],
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  final double t;
  final Color color;
  const _RadarPainter({required this.t, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 6;

    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = AppColors.gold.withValues(alpha: 0.45),
    );

    for (var i = 0; i < 3; i++) {
      final p = (t + i / 3) % 1;
      canvas.drawCircle(
        c,
        r * (0.25 + 0.75 * p),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = color.withValues(alpha: 0.45 * (1 - p)),
      );
    }

    final sweep = SweepGradient(
      startAngle: 0,
      endAngle: math.pi * 2,
      transform: GradientRotation(t * math.pi * 2),
      colors: [color.withValues(alpha: 0), color.withValues(alpha: 0.28)],
      stops: const [0.75, 1],
    );
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = sweep.createShader(Rect.fromCircle(center: c, radius: r)),
    );
  }

  @override
  bool shouldRepaint(_RadarPainter old) => old.t != t || old.color != color;
}
