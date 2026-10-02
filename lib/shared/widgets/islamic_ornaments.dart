import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:deen_companion/core/motion/motion.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../core/theme/app_colors.dart';

/// Points of an eight-pointed star (Khatim) — 16 alternating vertices.
Path eightStarPath(Offset c, double outer, {double inner = 0.72}) {
  final path = Path();
  for (var i = 0; i < 16; i++) {
    final r = i.isEven ? outer : outer * inner;
    final a = -math.pi / 2 + i * math.pi / 8;
    final p = Offset(c.dx + r * math.cos(a), c.dy + r * math.sin(a));
    i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
  }
  return path..close();
}

/// Tiled eight-pointed-star lattice, drawn as line-work. Used at very low
/// opacity as a texture behind hero areas.
class GeometricPatternPainter extends CustomPainter {
  final Color color;
  final double cell;
  final double strokeWidth;

  const GeometricPatternPainter({
    required this.color,
    this.cell = 44,
    this.strokeWidth = 0.8,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    final r = cell * 0.42;
    for (var y = 0.0; y < size.height + cell; y += cell) {
      for (var x = 0.0; x < size.width + cell; x += cell) {
        final c = Offset(x + cell / 2, y + cell / 2);
        for (final rot in [0.0, math.pi / 4]) {
          final sq = Path();
          for (var i = 0; i < 4; i++) {
            final a = rot + math.pi / 4 + i * math.pi / 2;
            final p = Offset(c.dx + r * math.cos(a), c.dy + r * math.sin(a));
            i == 0 ? sq.moveTo(p.dx, p.dy) : sq.lineTo(p.dx, p.dy);
          }
          canvas.drawPath(sq..close(), paint);
        }
        canvas.drawCircle(Offset(x, y), 1.4, paint);
      }
    }
  }

  @override
  bool shouldRepaint(GeometricPatternPainter old) =>
      old.color != color || old.cell != cell || old.strokeWidth != strokeWidth;
}

/// Convenience wrapper: pattern as a non-interactive, isolated layer.
class GeometricPattern extends StatelessWidget {
  final Color color;
  final double cell;
  const GeometricPattern({super.key, required this.color, this.cell = 44});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          painter: GeometricPatternPainter(color: color, cell: cell),
          size: Size.infinite,
        ),
      ),
    );
  }
}

/// Filled eight-pointed star with an optional outline and inner outline
/// ring — the medallion shape behind Names and numbers.
class StarPainter extends CustomPainter {
  final Color fill;
  final Color? stroke;
  final double strokeWidth;
  final double inner;
  final double rotation;

  const StarPainter({
    required this.fill,
    this.stroke,
    this.strokeWidth = 1.2,
    this.inner = 0.72,
    this.rotation = 0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final outer = size.shortestSide / 2 - strokeWidth;
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(rotation);
    canvas.translate(-c.dx, -c.dy);
    final path = eightStarPath(c, outer, inner: inner);
    canvas.drawPath(path, Paint()..color = fill);
    if (stroke != null) {
      canvas.drawPath(
        path,
        Paint()
          ..color = stroke!
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeJoin = StrokeJoin.round,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(StarPainter old) =>
      old.fill != fill ||
      old.stroke != stroke ||
      old.inner != inner ||
      old.rotation != rotation;
}

/// Star-shaped number badge.
class StarBadge extends StatelessWidget {
  final String label;
  final double size;
  final Color fill;
  final Color? stroke;
  final Color textColor;

  const StarBadge({
    super.key,
    required this.label,
    required this.size,
    required this.fill,
    required this.textColor,
    this.stroke,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: StarPainter(fill: fill, stroke: stroke, strokeWidth: 1),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: size * 0.3,
              fontWeight: FontWeight.w700,
              color: textColor,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}

/// Arc progress ring painted around a medallion.
class RingPainter extends CustomPainter {
  final double progress;
  final Color track;
  final Color color;
  final double width;

  const RingPainter({
    required this.progress,
    required this.track,
    required this.color,
    this.width = 6,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final arcRect = rect.deflate(width / 2);
    canvas.drawArc(
      arcRect,
      0,
      math.pi * 2,
      false,
      Paint()
        ..color = track
        ..style = PaintingStyle.stroke
        ..strokeWidth = width,
    );
    if (progress > 0) {
      canvas.drawArc(
        arcRect,
        -math.pi / 2,
        math.pi * 2 * progress.clamp(0.0, 1.0),
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = width
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(RingPainter old) =>
      old.progress != progress || old.color != color || old.track != track;
}

/// Small frosted circular button used on dark hero areas.
class GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;

  /// 0 = subtle glass over a hero image, 1 = clearly outlined for use on a
  /// solid bar, where plain glass would blend into the background.
  final double strength;

  const GlassIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.strength = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip ?? '',
      child: PressScale(
        scale: AppMotion.pressScaleSmall,
        child: InkResponse(
          onTap: onPressed,
          radius: 26.w,
          child: Container(
            width: 40.w,
            height: 40.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.onHeroSurface.withValues(
                alpha: 0.12 + 0.10 * strength,
              ),
              border: Border.all(
                color: Color.lerp(
                  AppColors.onHeroSurface.withValues(alpha: 0.18),
                  AppColors.gold.withValues(alpha: 0.8),
                  strength,
                )!,
              ),
            ),
            child: Icon(icon, size: 20.sp, color: AppColors.onHeroSurface),
          ),
        ),
      ),
    );
  }
}

/// App shared-axis route used by the redesigned feature screens.
Route<T> fadeScaleRoute<T>(WidgetBuilder builder) {
  return PageRouteBuilder<T>(
    transitionDuration: AppMotion.page,
    reverseTransitionDuration: AppMotion.pageReverse,
    pageBuilder: (context, _, _) => builder(context),
    transitionsBuilder: (context, animation, secondary, child) =>
        buildAppTransition(context, animation, secondary, child),
  );
}
