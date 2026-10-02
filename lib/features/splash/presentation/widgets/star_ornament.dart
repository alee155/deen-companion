import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Eight-pointed star (two overlaid squares) — the classic Islamic geometric
/// motif. [progress] 0→1 draws the outline in and settles the rotation.
class StarOrnament extends StatelessWidget {
  const StarOrnament({
    super.key,
    required this.progress,
    required this.color,
    this.size = 260,
  });

  final double progress;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        size: Size.square(size),
        painter: _StarPainter(progress, color),
      ),
    );
  }
}

class _StarPainter extends CustomPainter {
  _StarPainter(this.progress, this.color);

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round
      ..color = color;

    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate((1 - Curves.easeOutCubic.transform(progress)) * -math.pi / 4);

    for (var i = 0; i < 2; i++) {
      final path = Path();
      for (var k = 0; k < 4; k++) {
        final a = math.pi / 4 * i + math.pi / 2 * k;
        final p = Offset(math.cos(a), math.sin(a)) * r;
        k == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
      }
      path.close();
      for (final m in path.computeMetrics()) {
        canvas.drawPath(m.extractPath(0, m.length * progress), paint);
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_StarPainter old) =>
      old.progress != progress || old.color != color;
}
