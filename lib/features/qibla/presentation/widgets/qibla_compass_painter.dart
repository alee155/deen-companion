import 'dart:math' as math;
import 'package:flutter/material.dart';

class QiblaRingPainter extends CustomPainter {
  final Color ringColor;
  final Color labelColor;
  final Color dotColor;

  QiblaRingPainter({
    required this.ringColor,
    required this.labelColor,
    required this.dotColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2;

    final ringPaint = Paint()
      ..color = ringColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(center, radius - 2, ringPaint);

    // Small dots at the 4 diagonals only — minimal, not a dense tick ring.
    for (final deg in [45, 135, 225, 315]) {
      final angle = deg * math.pi / 180;
      final offset = Offset(
        center.dx + (radius - 14) * math.sin(angle),
        center.dy - (radius - 14) * math.cos(angle),
      );
      canvas.drawCircle(offset, 2.5, Paint()..color = dotColor);
    }

    _label(canvas, center, radius - 40, 0, 'N');
    _label(canvas, center, radius - 40, 90, 'E');
    _label(canvas, center, radius - 40, 180, 'S');
    _label(canvas, center, radius - 40, 270, 'W');
  }

  void _label(
    Canvas canvas,
    Offset center,
    double radius,
    double angleDeg,
    String text,
  ) {
    final angle = angleDeg * math.pi / 180;
    final offset = Offset(
      center.dx + radius * math.sin(angle),
      center.dy - radius * math.cos(angle),
    );
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: labelColor,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      offset - Offset(painter.width / 2, painter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant QiblaRingPainter oldDelegate) => false;
}
