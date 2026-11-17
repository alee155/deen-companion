import 'package:flutter/material.dart';

/// The Explore tab's icon: three rounded squares and a magnifier where the
/// fourth would be. Material has no such glyph, so it is drawn.
class ExploreNavIcon extends StatelessWidget {
  final Color color;
  final double size;
  const ExploreNavIcon({super.key, required this.color, required this.size});

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: _ExplorePainter(color));
}

class _ExplorePainter extends CustomPainter {
  final Color color;
  _ExplorePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final stroke = s * 0.085;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    // A 2x2 grid with the bottom-right cell taken by the magnifier.
    final cell = s * 0.36;
    final gap = s * 0.64;
    final r = Radius.circular(s * 0.08);
    final top = stroke / 2 + s * 0.04;
    for (final o in [
      Offset(top, top),
      Offset(top + gap - stroke, top),
      Offset(top, top + gap - stroke),
    ]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(o.dx, o.dy, cell, cell), r),
        paint,
      );
    }

    final lens = Offset(
      top + gap - stroke + cell * 0.36,
      top + gap - stroke + cell * 0.36,
    );
    canvas.drawCircle(lens, cell * 0.34, paint);
    canvas.drawLine(
      lens + Offset(cell * 0.34, cell * 0.34) * 0.72,
      Offset(s - stroke, s - stroke),
      paint,
    );
  }

  @override
  bool shouldRepaint(_ExplorePainter old) => old.color != color;
}
