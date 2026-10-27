import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../../../core/router/app_routes.dart';
import '../../data/prayer_alarm_channel.dart';
import '../../domain/prayer_alarm_launch.dart';

/// What the user lands on after tapping "Open" on the iOS alarm screen: the
/// same page the Android alarm shows (ringing logo, prayer, time, the verse,
/// Dismiss and Snooze), since the system alarm itself can't be restyled.
class PrayerAlarmScreen extends ConsumerStatefulWidget {
  final PrayerAlarmLaunch launch;
  const PrayerAlarmScreen({super.key, required this.launch});

  @override
  ConsumerState<PrayerAlarmScreen> createState() => _PrayerAlarmScreenState();
}

class _PrayerAlarmScreenState extends ConsumerState<PrayerAlarmScreen>
    with TickerProviderStateMixin {
  static const _heroStart = Color(0xFF1A1A1A);
  static const _heroEnd = Color(0xFFC96A2E);
  static const _orange = Color(0xFFF08232);
  static const _onOrange = Color(0xFF1A1A1A);
  static const _goldLight = Color(0xFFF3E7D0);
  static const _onHero = Color(0xFFFCFBF4);
  static const _glass = Color(0x1FFFFFFF);
  static const _glassBorder = Color(0x2EFFFFFF);

  static const _verseArabic =
      'إِنَّ ٱلصَّلَوٰةَ كَانَتْ عَلَى ٱلْمُؤْمِنِينَ كِتَٰبًا مَّوْقُوتًا';
  static const _verseTranslation =
      'Indeed, prayer has been decreed upon the believers a decree of '
      'specified times.';
  static const _verseReference = 'Qur’an 4:103';

  late final _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  );
  late final _spinA = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 48),
  );
  late final _spinB = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 70),
  );
  late final _ripple = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  );
  late final _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  bool _snoozing = false;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    // Honour "reduce motion": show the finished page, nothing moving.
    if (MediaQuery.disableAnimationsOf(context)) {
      _entrance.value = 1;
      return;
    }
    _entrance.forward();
    _spinA.repeat();
    _spinB.repeat();
    _ripple.repeat();
    Future<void>.delayed(const Duration(milliseconds: 900), () {
      if (mounted) _pulse.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _entrance.dispose();
    _spinA.dispose();
    _spinB.dispose();
    _ripple.dispose();
    _pulse.dispose();
    super.dispose();
  }

  void _close() {
    HapticFeedback.selectionClick();
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.home);
    }
  }

  Future<void> _snooze() async {
    if (_snoozing) return;
    HapticFeedback.selectionClick();
    setState(() => _snoozing = true);
    final launch = widget.launch;
    final ok = await ref
        .read(prayerAlarmChannelProvider)
        .snoozeAlarm(
          minutes: launch.snoozeMinutes,
          prayerName: launch.prayerName,
          label: launch.label,
        );
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Snoozed for ${launch.snoozeMinutes} minutes'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      _close();
    } else {
      setState(() => _snoozing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Couldn’t snooze. Check the alarm permission.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// Fade and rise, staggered by [index], like the Android entrance.
  Widget _rise(int index, Widget child) {
    final start = (0.14 + 0.07 * index).clamp(0.0, 0.8);
    final curve = CurvedAnimation(
      parent: _entrance,
      curve: Interval(
        start,
        (start + 0.4).clamp(0.0, 1.0),
        curve: Curves.decelerate,
      ),
    );
    return AnimatedBuilder(
      animation: curve,
      builder: (_, c) => Opacity(
        opacity: curve.value,
        child: Transform.translate(
          offset: Offset(0, 28 * (1 - curve.value)),
          child: c,
        ),
      ),
      child: child,
    );
  }

  Widget _logoStack() {
    final pop = CurvedAnimation(
      parent: _entrance,
      curve: const Interval(0, 0.48, curve: Curves.easeOutBack),
    );
    return SizedBox(
      width: 150,
      height: 150,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          _spinning(_spinA, 1, _StarPainter(diamond: false)),
          _spinning(_spinB, -1, _StarPainter(diamond: true)),
          for (var i = 0; i < 3; i++) _ripplering(i),
          AnimatedBuilder(
            animation: pop,
            builder: (_, child) => Opacity(
              opacity: pop.value.clamp(0.0, 1.0),
              child: Transform.scale(
                scale: 0.6 + 0.4 * pop.value,
                child: child,
              ),
            ),
            child: Container(
              width: 104,
              height: 104,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: _orange, width: 1.5),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x40000000),
                    blurRadius: 16,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: Image.asset(
                'assets/images/alarm_logo.png',
                fit: BoxFit.contain,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _spinning(
    AnimationController c,
    int direction,
    CustomPainter painter,
  ) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: c,
        builder: (_, child) => Transform.rotate(
          angle: direction * c.value * 2 * math.pi,
          child: child,
        ),
        child: Opacity(
          opacity: 0.22,
          child: SizedBox(
            width: 300,
            height: 300,
            child: CustomPaint(painter: painter),
          ),
        ),
      ),
    );
  }

  /// One sonar ring: grows and fades, offset from its neighbours.
  Widget _ripplering(int i) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _ripple,
        builder: (_, _) {
          final phase = (_ripple.value - i * 1050 / 3200) % 1.0;
          final eased = Curves.decelerate.transform(
            phase < 0 ? phase + 1 : phase,
          );
          return Opacity(
            opacity: _ripple.isAnimating ? 0.55 * (1 - eased) : 0,
            child: Transform.scale(
              scale: 1 + 1.7 * eased,
              child: Container(
                width: 104,
                height: 104,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: _orange, width: 2),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _glassBox({
    required Widget child,
    required double radius,
    Color? fill,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: fill ?? _glass,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: _glassBorder),
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final launch = widget.launch;
    final time = DateFormat('h:mm a').format(launch.time);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _heroStart,
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_heroStart, _heroEnd],
            ),
          ),
          child: SafeArea(
            child: CustomScrollView(
              physics: const ClampingScrollPhysics(),
              slivers: [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                    child: Column(
                      children: [
                        const Spacer(),
                        _logoStack(),
                        const SizedBox(height: 26),
                        _rise(
                          0,
                          _glassBox(
                            radius: 16,
                            child: const Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 6,
                              ),
                              child: Text(
                                'Time to pray',
                                style: TextStyle(
                                  color: _goldLight,
                                  fontSize: 13,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        _rise(
                          1,
                          Text(
                            launch.displayName,
                            style: const TextStyle(
                              color: _onHero,
                              fontSize: 46,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        _rise(
                          2,
                          Text(
                            time,
                            style: const TextStyle(
                              color: _orange,
                              fontSize: 26,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(height: 26),
                        _rise(
                          3,
                          SizedBox(
                            width: double.infinity,
                            child: _glassBox(
                              radius: 22,
                              fill: const Color(0x14FFFFFF),
                              child: Padding(
                                padding: const EdgeInsets.all(18),
                                child: Column(
                                  children: [
                                    const Text(
                                      _verseArabic,
                                      textAlign: TextAlign.center,
                                      textDirection: TextDirection.rtl,
                                      style: TextStyle(
                                        fontFamily: 'AmiriQuran',
                                        color: _onHero,
                                        fontSize: 22,
                                        height: 1.6,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    const Text(
                                      _verseTranslation,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: _onHero,
                                        fontSize: 14,
                                        height: 1.3,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    const Text(
                                      _verseReference,
                                      style: TextStyle(
                                        color: _goldLight,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        const Spacer(),
                        AnimatedBuilder(
                          animation: _pulse,
                          builder: (_, child) => Transform.scale(
                            scale:
                                1 +
                                0.035 *
                                    Curves.easeInOut.transform(_pulse.value),
                            child: child,
                          ),
                          child: SizedBox(
                            width: double.infinity,
                            height: 58,
                            child: FilledButton(
                              onPressed: _snoozing ? null : _close,
                              style: FilledButton.styleFrom(
                                backgroundColor: _orange,
                                foregroundColor: _onOrange,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                textStyle: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              child: const Text('Dismiss'),
                            ),
                          ),
                        ),
                        if (launch.canSnooze) ...[
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: OutlinedButton(
                              onPressed: _snoozing ? null : _snooze,
                              style: OutlinedButton.styleFrom(
                                backgroundColor: _glass,
                                foregroundColor: _onHero,
                                side: const BorderSide(color: _glassBorder),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                textStyle: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              child: Text('Snooze ${launch.snoozeMinutes} min'),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The two thin geometric outlines behind the logo: nested squares, and
/// nested diamonds, drawn on the same 100-unit grid as the Android assets.
class _StarPainter extends CustomPainter {
  final bool diamond;
  _StarPainter({required this.diamond});

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 100;
    final paint = Paint()
      ..color = const Color(0xFFF3E7D0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5 * k;

    Path poly(List<Offset> pts) {
      final p = Path()..moveTo(pts.first.dx * k, pts.first.dy * k);
      for (final o in pts.skip(1)) {
        p.lineTo(o.dx * k, o.dy * k);
      }
      return p..close();
    }

    if (diamond) {
      canvas.drawPath(
        poly(const [
          Offset(50, 2),
          Offset(98, 50),
          Offset(50, 98),
          Offset(2, 50),
        ]),
        paint,
      );
      canvas.drawPath(
        poly(const [
          Offset(50, 20),
          Offset(80, 50),
          Offset(50, 80),
          Offset(20, 50),
        ]),
        paint,
      );
    } else {
      canvas.drawPath(
        poly(const [
          Offset(14, 14),
          Offset(86, 14),
          Offset(86, 86),
          Offset(14, 86),
        ]),
        paint,
      );
      canvas.drawPath(
        poly(const [
          Offset(30, 30),
          Offset(70, 30),
          Offset(70, 70),
          Offset(30, 70),
        ]),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_StarPainter old) => old.diamond != diamond;
}
