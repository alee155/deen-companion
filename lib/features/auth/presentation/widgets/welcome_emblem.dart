import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/motion/motion.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../splash/presentation/splash_branding.dart';

/// The Welcome screen's centrepiece, continuing the splash identity: the app
/// logo on a badge, ringed by an eight-pointed star whose two squares turn
/// slowly in opposite directions, with soft ripples leaving the badge. Never
/// stops while the screen is up; frozen (and ripple-free) when the system
/// asks for reduced motion.
class WelcomeEmblem extends StatefulWidget {
  final double size;
  const WelcomeEmblem({super.key, required this.size});

  @override
  State<WelcomeEmblem> createState() => _WelcomeEmblemState();
}

class _WelcomeEmblemState extends State<WelcomeEmblem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 24),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (context.motion.reduced) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    final badge = size * 0.42;
    // final reduced = context.motion.reduced;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          RepaintBoundary(
            child: CustomPaint(
              size: Size.square(size),
              painter: _LatticePainter(_c, AppColors.goldLight),
            ),
          ),
          // if (!reduced)
          //   for (var i = 0; i < 2; i++)
          // AnimatedBuilder(
          //   animation: _c,
          //   builder: (_, _) {
          //     // Eight ripple cycles per 24s turn: one every 3s, the two
          //     // rings half a cycle apart.
          //     final phase = (_c.value * 8 + i * 0.5) % 1;
          //     return Opacity(
          //       opacity: 0.5 * (1 - phase),
          //       child: Container(
          //         width: badge * (1 + 1.1 * phase),
          //         height: badge * (1 + 1.1 * phase),
          //         decoration: BoxDecoration(
          //           shape: BoxShape.circle,
          //           border: Border.all(
          //             color: AppColors.emeraldInk,
          //             width: 1.6,
          //           ),
          //         ),
          //       ),
          //     );
          //   },
          // ),
          Container(
            width: badge,
            height: badge,
            decoration: BoxDecoration(
              // border: Border.all(color: AppColors.emeraldInk, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: AppColors.emeraldInk.withValues(alpha: 0.35),
                  blurRadius: 34,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: ClipOval(
              child: Image.asset(
                SplashBranding.logoAsset,
                width: badge,
                height: badge,
                fit: BoxFit.cover,
              ),
            ),
          ).popIn(),
        ],
      ),
    );
  }
}

/// Two nested eight-pointed stars (each a pair of squares), the outer turning
/// clockwise and the inner counter-clockwise.
class _LatticePainter extends CustomPainter {
  final Animation<double> turn;
  final Color color;
  _LatticePainter(this.turn, this.color) : super(repaint: turn);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final outer = size.width / 2 * 0.98;
    final inner = size.width / 2 * 0.66;
    final angle = turn.value * 2 * math.pi;

    void star(double radius, double rotation, double alpha) {
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = color.withValues(alpha: alpha);
      for (var k = 0; k < 2; k++) {
        final path = Path();
        for (var i = 0; i < 4; i++) {
          final a = rotation + math.pi / 4 * k + math.pi / 2 * i;
          final p = c + Offset(math.cos(a), math.sin(a)) * radius;
          i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
        }
        path.close();
        canvas.drawPath(path, paint);
      }
    }

    star(outer, angle, 0.30);
    star(inner, -angle * 1.4, 0.24);
  }

  @override
  bool shouldRepaint(_LatticePainter old) => old.color != color;
}
