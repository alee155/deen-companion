import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/islamic_ornaments.dart';

/// The player's artwork: the arch of a mihrab (the prayer niche) holding the
/// surah's name in Quranic calligraphy, over a slowly turning geometric
/// pattern. It is this app's own shape, not a square cover: a recitation has
/// no album art, so the artwork says what it is.
///
/// While playing it sits at full size, glows and the pattern turns; paused, it
/// settles slightly smaller and still.
class MihrabArtwork extends StatefulWidget {
  final String arabicTitle;

  /// The surah number, shown in a small star medallion above the name.
  final int? number;
  final bool isPlaying;
  final double width;

  const MihrabArtwork({
    super.key,
    required this.arabicTitle,
    required this.number,
    required this.isPlaying,
    required this.width,
  });

  /// Height for a given width: a little taller than wide, like a niche.
  static double heightFor(double width) => width * 1.2;

  @override
  State<MihrabArtwork> createState() => _MihrabArtworkState();
}

class _MihrabArtworkState extends State<MihrabArtwork>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 120),
  );

  bool _reduceMotion = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    _syncSpin();
  }

  @override
  void didUpdateWidget(MihrabArtwork old) {
    super.didUpdateWidget(old);
    _syncSpin();
  }

  void _syncSpin() {
    if (widget.isPlaying && !_reduceMotion) {
      if (!_spin.isAnimating) _spin.repeat();
    } else {
      _spin.stop();
    }
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  /// `2` -> `٢`, as the Quran numbers its surahs.
  static String _arabicIndic(int n) => n
      .toString()
      .split('')
      .map((d) => String.fromCharCode(0x0660 + int.parse(d)))
      .join();

  @override
  Widget build(BuildContext context) {
    final w = widget.width;
    final h = MihrabArtwork.heightFor(w);
    final size = Size(w, h);

    return Semantics(
      image: true,
      label: 'Surah ${widget.arabicTitle}',
      child: AnimatedScale(
        scale: widget.isPlaying ? 1.0 : 0.9,
        duration: _reduceMotion
            ? Duration.zero
            : const Duration(milliseconds: 520),
        curve: Curves.easeOutBack,
        child: SizedBox(
          width: w,
          height: h,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Glow, brighter while playing.
              Positioned.fill(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(end: widget.isPlaying ? 1.0 : 0.0),
                  duration: _reduceMotion
                      ? Duration.zero
                      : const Duration(milliseconds: 700),
                  builder: (_, glow, _) => CustomPaint(
                    painter: _GlowPainter(
                      color: AppColors.amber,
                      strength: 0.16 + 0.34 * glow,
                    ),
                  ),
                ),
              ),
              ClipPath(
                clipper: _MihrabClipper(),
                child: SizedBox.expand(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          const Color(0xFF1B1511),
                          Color.lerp(
                            const Color(0xFF3A2112),
                            AppColors.amberDeep,
                            0.25,
                          )!,
                          AppColors.amberDeep,
                        ],
                        stops: const [0, 0.55, 1],
                      ),
                    ),
                    child: Stack(
                      children: [
                        // The pattern, large enough to stay covering while it
                        // turns.
                        Positioned.fill(
                          child: OverflowBox(
                            maxWidth: w * 1.9,
                            maxHeight: h * 1.9,
                            child: AnimatedBuilder(
                              animation: _spin,
                              builder: (_, child) => Transform.rotate(
                                angle: _spin.value * 2 * math.pi,
                                child: child,
                              ),
                              child: SizedBox(
                                width: w * 1.9,
                                height: h * 1.9,
                                child: GeometricPattern(
                                  color: AppColors.goldLight.withValues(
                                    alpha: 0.16,
                                  ),
                                  cell: w * 0.2,
                                ),
                              ),
                            ),
                          ),
                        ),
                        // A soft light behind the name.
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: RadialGradient(
                                center: const Alignment(0, 0.1),
                                radius: 0.75,
                                colors: [
                                  AppColors.amber.withValues(alpha: 0.30),
                                  AppColors.amber.withValues(alpha: 0),
                                ],
                              ),
                            ),
                          ),
                        ),
                        _Inscription(
                          width: w,
                          title: widget.arabicTitle,
                          number: widget.number == null
                              ? null
                              : _arabicIndic(widget.number!),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // The niche outlines: the edge, and a thinner one inside it.
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(painter: _OutlinePainter(size: size)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Inscription extends StatelessWidget {
  final double width;
  final String title;
  final String? number;
  const _Inscription({
    required this.width,
    required this.title,
    required this.number,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        width * 0.12,
        width * 0.42,
        width * 0.12,
        width * 0.12,
      ),
      child: Column(
        children: [
          if (number != null)
            SizedBox(
              width: width * 0.15,
              height: width * 0.15,
              child: CustomPaint(
                painter: _StarMedallionPainter(),
                child: Center(
                  child: Text(
                    number!,
                    style: TextStyle(
                      fontFamily: 'AmiriQuran',
                      fontSize: width * 0.065,
                      color: AppColors.goldLight,
                      height: 1,
                    ),
                  ),
                ),
              ),
            ),
          SizedBox(height: width * 0.04),
          Expanded(
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    fontFamily: 'AmiriQuran',
                    fontSize: width * 0.2,
                    height: 1.3,
                    color: AppColors.onHeroSurface,
                    shadows: const [
                      Shadow(color: Color(0x66000000), blurRadius: 12),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Text(
            'SURAH',
            style: TextStyle(
              fontSize: width * 0.04,
              letterSpacing: width * 0.012,
              fontWeight: FontWeight.w600,
              color: AppColors.goldLight.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

/// The mihrab outline: straight walls, a pointed arch, rounded base.
Path mihrabPath(Size size, {double inset = 0}) {
  final w = size.width, h = size.height;
  final left = inset, right = w - inset, top = inset, bottom = h - inset;
  final cx = w / 2;
  final r = math.max(8.0, w * 0.1 - inset * 0.4);
  final shoulder = h * 0.4; // where the walls turn into the arch

  return Path()
    ..moveTo(left, bottom - r)
    ..lineTo(left, shoulder)
    ..cubicTo(left, shoulder - h * 0.2, cx - w * 0.3, top + h * 0.08, cx, top)
    ..cubicTo(
      cx + w * 0.3,
      top + h * 0.08,
      right,
      shoulder - h * 0.2,
      right,
      shoulder,
    )
    ..lineTo(right, bottom - r)
    ..arcToPoint(Offset(right - r, bottom), radius: Radius.circular(r))
    ..lineTo(left + r, bottom)
    ..arcToPoint(Offset(left, bottom - r), radius: Radius.circular(r))
    ..close();
}

class _MihrabClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) => mihrabPath(size);

  @override
  bool shouldReclip(_MihrabClipper old) => false;
}

class _OutlinePainter extends CustomPainter {
  final Size size;
  _OutlinePainter({required this.size});

  @override
  void paint(Canvas canvas, Size _) {
    canvas.drawPath(
      mihrabPath(size, inset: 0.6),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = AppColors.gold.withValues(alpha: 0.75),
    );
    canvas.drawPath(
      mihrabPath(size, inset: size.width * 0.045),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..color = AppColors.goldLight.withValues(alpha: 0.32),
    );
  }

  @override
  bool shouldRepaint(_OutlinePainter old) => old.size != size;
}

class _GlowPainter extends CustomPainter {
  final Color color;
  final double strength;
  const _GlowPainter({required this.color, required this.strength});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      mihrabPath(size),
      Paint()
        ..color = color.withValues(alpha: strength)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, size.width * 0.14),
    );
  }

  @override
  bool shouldRepaint(_GlowPainter old) =>
      old.strength != strength || old.color != color;
}

/// An eight-pointed star outline (two squares, one turned 45 degrees).
class _StarMedallionPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = AppColors.goldLight.withValues(alpha: 0.8);
    for (final turn in [0.0, math.pi / 4]) {
      final p = Path();
      for (var i = 0; i < 4; i++) {
        final a = turn + math.pi / 4 + i * math.pi / 2;
        final o = Offset(c.dx + r * math.cos(a), c.dy + r * math.sin(a));
        i == 0 ? p.moveTo(o.dx, o.dy) : p.lineTo(o.dx, o.dy);
      }
      canvas.drawPath(p..close(), paint);
    }
  }

  @override
  bool shouldRepaint(_StarMedallionPainter old) => false;
}
