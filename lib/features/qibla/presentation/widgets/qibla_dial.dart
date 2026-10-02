import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/motion/motion.dart';
import '../../../../core/theme/app_colors.dart';
import '../utils/qibla_math.dart';

Color get qiblaAlignedColor =>
    Color.lerp(AppColors.success, Colors.white, 0.28)!;

/// The Qibla compass dial.
///
/// The dial card rotates against the device [heading] (true north based) so
/// N/E/S/W always mark real directions, while a beam and Kaaba badge point at
/// [qiblaDirection]. The fixed marker at the top is where the phone is
/// pointing: when the badge sits under it, you are facing the Qibla.
///
/// Heading changes are animated along the shortest path (no spinning the long
/// way round at 359° → 0°), and the dial plays a one-shot sweep when it first
/// appears. A soft glow pulses while [aligned].
class QiblaDial extends StatefulWidget {
  /// Current true-north heading in degrees, or null for a static dial that
  /// simply shows the bearing from north (no compass available).
  final double? heading;
  final double qiblaDirection;
  final bool aligned;
  final bool locked;
  final double size;

  const QiblaDial({
    super.key,
    required this.heading,
    required this.qiblaDirection,
    required this.aligned,
    required this.size,
    this.locked = false,
  });

  @override
  State<QiblaDial> createState() => _QiblaDialState();
}

class _QiblaDialState extends State<QiblaDial> with TickerProviderStateMixin {
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  // Unwrapped (continuous) angles so tweens never wrap the long way round.
  double _headingUnwrapped = 0;
  double _diffUnwrapped = 0;
  bool _introStarted = false;

  double get _heading => widget.heading ?? 0;
  double get _diff => widget.heading == null
      ? widget.qiblaDirection
      : shortestAngleDiff(widget.qiblaDirection, _heading);

  @override
  void initState() {
    super.initState();
    _headingUnwrapped = _heading;
    _diffUnwrapped = _diff;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_introStarted) return;
    _introStarted = true;
    if (context.motion.reduced) {
      _intro.value = 1;
    } else {
      _intro.forward();
    }
    _syncPulse();
  }

  @override
  void didUpdateWidget(QiblaDial old) {
    super.didUpdateWidget(old);
    if (widget.heading != null) {
      _headingUnwrapped += shortestAngleDiff(_heading, _headingUnwrapped);
    }
    _diffUnwrapped += shortestAngleDiff(_diff, _diffUnwrapped);
    if (old.aligned != widget.aligned) _syncPulse();
  }

  void _syncPulse() {
    if (widget.aligned && !context.motion.reduced) {
      _pulse.repeat(reverse: true);
    } else {
      _pulse.animateTo(0, duration: AppMotion.fast);
    }
  }

  @override
  void dispose() {
    _intro.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    final accent = widget.aligned ? qiblaAlignedColor : AppColors.amber;
    final motion = context.motion;
    final glide = motion.duration(const Duration(milliseconds: 260));

    return AnimatedBuilder(
      animation: Listenable.merge([_intro, _pulse]),
      builder: (context, _) {
        final t = Curves.easeOutCubic.transform(_intro.value);
        final beamT = Curves.easeOut.transform(
          ((_intro.value - 0.45) / 0.55).clamp(0.0, 1.0),
        );
        // The dial arrives with a quarter-turn sweep that settles on the
        // real heading.
        final sweep = (1 - t) * -math.pi / 2;
        return Opacity(
          opacity: t,
          child: Transform.scale(
            scale: 0.86 + 0.14 * t,
            child: SizedBox(
              width: size,
              height: size,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Alignment glow.
                  Container(
                    width: size * 0.96,
                    height: size * 0.96,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: accent.withValues(
                            alpha: 0.16 + 0.26 * _pulse.value,
                          ),
                          blurRadius: 26 + 22 * _pulse.value,
                          spreadRadius: 1 + 5 * _pulse.value,
                        ),
                      ],
                    ),
                  ),
                  // Rotating dial face (north-up in the real world).
                  TweenAnimationBuilder<double>(
                    tween: Tween(end: _headingUnwrapped),
                    duration: glide,
                    curve: Curves.easeOutCubic,
                    builder: (context, h, child) => Transform.rotate(
                      angle: -h * math.pi / 180 + sweep,
                      child: child,
                    ),
                    child: RepaintBoundary(
                      child: CustomPaint(
                        size: Size.square(size),
                        painter: QiblaDialPainter(
                          ring: AppColors.gold,
                          tick: Colors.white,
                          north: AppColors.emeraldInk,
                          label: AppColors.onHeroSurface,
                        ),
                      ),
                    ),
                  ),
                  // Qibla beam + Kaaba badge, rotated to the Qibla bearing
                  // relative to where the phone points.
                  Opacity(
                    opacity: beamT,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(end: _diffUnwrapped),
                      duration: glide,
                      curve: Curves.easeOutCubic,
                      builder: (context, d, child) => Transform.rotate(
                        angle: d * math.pi / 180 + sweep,
                        child: child,
                      ),
                      child: _QiblaBeam(size: size, color: accent),
                    ),
                  ),
                  // Fixed "you are facing here" marker.
                  Positioned(top: -2, child: _FacingMarker(color: accent)),
                  // Hub.
                  _Hub(size: size * 0.13, color: accent, locked: widget.locked),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _QiblaBeam extends StatelessWidget {
  final double size;
  final Color color;
  const _QiblaBeam({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size.square(size),
            painter: _BeamPainter(color: color),
          ),
          Positioned(
            top: size * 0.085,
            child: _KaabaBadge(size: size * 0.17, color: color),
          ),
        ],
      ),
    );
  }
}

class _KaabaBadge extends StatelessWidget {
  final double size;
  final Color color;
  const _KaabaBadge({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: AppMotion.normal,
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(color: color, width: 2),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.55), blurRadius: 14),
        ],
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(size * 0.08),
        ),
        child: Align(
          alignment: const Alignment(0, -0.35),
          child: Container(height: size * 0.1, color: AppColors.gold),
        ),
      ),
    );
  }
}

class _FacingMarker extends StatelessWidget {
  final Color color;
  const _FacingMarker({required this.color});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(22.w, 16.w),
      painter: _TrianglePainter(color: color),
    );
  }
}

class _Hub extends StatelessWidget {
  final double size;
  final Color color;
  final bool locked;
  const _Hub({required this.size, required this.color, required this.locked});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: AppMotion.normal,
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [Colors.white, color],
          stops: const [0.15, 1],
        ),
        border: Border.all(color: AppColors.heroSurface, width: 3),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 10),
        ],
      ),
      child: AnimatedSwitcher(
        duration: AppMotion.fast,
        child: locked
            ? Icon(
                Icons.lock_rounded,
                key: const ValueKey('lock'),
                size: size * 0.5,
                color: AppColors.heroSurface,
              )
            : const SizedBox(key: ValueKey('open')),
      ),
    );
  }
}

class _TrianglePainter extends CustomPainter {
  final Color color;
  const _TrianglePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawShadow(path, color, 6, true);
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_TrianglePainter old) => old.color != color;
}

class _BeamPainter extends CustomPainter {
  final Color color;
  const _BeamPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    final rect = Rect.fromCenter(
      center: Offset(c.dx, c.dy - r * 0.34),
      width: 5,
      height: r * 0.68,
    );
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color, color.withValues(alpha: 0)],
      ).createShader(rect);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(3)),
      paint,
    );
  }

  @override
  bool shouldRepaint(_BeamPainter old) => old.color != color;
}

/// Static dial face: disc, ring, ticks, cardinal + degree labels and a faint
/// eight-point star. Painted once and rotated as a whole, so it never needs
/// to repaint while the compass moves.
class QiblaDialPainter extends CustomPainter {
  final Color ring;
  final Color tick;
  final Color north;
  final Color label;

  const QiblaDialPainter({
    required this.ring,
    required this.tick,
    required this.north,
    required this.label,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 6;

    // Disc.
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFF2C2924),
            AppColors.heroSurface,
            const Color(0xFF0E0E0E),
          ],
          stops: const [0, 0.7, 1],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );

    // Gold rim (double line).
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = ring.withValues(alpha: 0.85),
    );
    canvas.drawCircle(
      c,
      r - 8,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = ring.withValues(alpha: 0.35),
    );

    // Faint eight-point star behind the needle.
    final star = Path();
    for (var i = 0; i < 16; i++) {
      final rad = (i.isEven ? r * 0.56 : r * 0.34);
      final a = i * math.pi / 8;
      final p = Offset(c.dx + rad * math.sin(a), c.dy - rad * math.cos(a));
      i == 0 ? star.moveTo(p.dx, p.dy) : star.lineTo(p.dx, p.dy);
    }
    star.close();
    canvas.drawPath(
      star,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = ring.withValues(alpha: 0.22),
    );

    // Ticks.
    for (var deg = 0; deg < 360; deg += 5) {
      final major = deg % 30 == 0;
      final mid = deg % 15 == 0;
      final len = major ? 14.0 : (mid ? 9.0 : 5.0);
      final a = deg * math.pi / 180;
      final outer = r - 10;
      final p1 = Offset(c.dx + outer * math.sin(a), c.dy - outer * math.cos(a));
      final p2 = Offset(
        c.dx + (outer - len) * math.sin(a),
        c.dy - (outer - len) * math.cos(a),
      );
      canvas.drawLine(
        p1,
        p2,
        Paint()
          ..strokeWidth = major ? 2 : 1
          ..strokeCap = StrokeCap.round
          ..color = (deg == 0 ? north : tick).withValues(
            alpha: major ? 0.85 : (mid ? 0.45 : 0.25),
          ),
      );
    }

    // Labels.
    const cardinals = {0: 'N', 90: 'E', 180: 'S', 270: 'W'};
    cardinals.forEach((deg, text) {
      _text(
        canvas,
        c,
        r - 46,
        deg.toDouble(),
        text,
        deg == 0 ? north : label,
        20,
        FontWeight.w800,
      );
    });
    for (var deg = 30; deg < 360; deg += 30) {
      if (deg % 90 == 0) continue;
      _text(
        canvas,
        c,
        r - 40,
        deg.toDouble(),
        '$deg',
        label.withValues(alpha: 0.55),
        10.5,
        FontWeight.w500,
      );
    }
  }

  // Labels are drawn upright on the dial's own frame (they rotate with it),
  // like a real compass card.
  void _text(
    Canvas canvas,
    Offset c,
    double radius,
    double deg,
    String text,
    Color color,
    double fontSize,
    FontWeight weight,
  ) {
    final a = deg * math.pi / 180;
    final pos = Offset(
      c.dx + radius * math.sin(a),
      c.dy - radius * math.cos(a),
    );
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: color, fontSize: fontSize, fontWeight: weight),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    canvas.save();
    canvas.translate(pos.dx, pos.dy);
    canvas.rotate(a);
    tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
    canvas.restore();
  }

  @override
  bool shouldRepaint(QiblaDialPainter old) =>
      old.ring != ring ||
      old.tick != tick ||
      old.north != north ||
      old.label != label;
}
