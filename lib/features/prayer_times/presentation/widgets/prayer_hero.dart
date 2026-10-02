import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../../../../core/motion/motion.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/islamic_ornaments.dart';
import '../../../home/presentation/providers/home_provider.dart';
import '../../domain/entities/prayer_times.dart';

const prayerLabels = {
  PrayerName.fajr: 'Fajr',
  PrayerName.dhuhr: 'Dhuhr',
  PrayerName.asr: 'Asr',
  PrayerName.maghrib: 'Maghrib',
  PrayerName.isha: 'Isha',
};

const prayerArabic = {
  PrayerName.fajr: 'الفجر',
  PrayerName.dhuhr: 'الظهر',
  PrayerName.asr: 'العصر',
  PrayerName.maghrib: 'المغرب',
  PrayerName.isha: 'العشاء',
};

const prayerIcons = {
  PrayerName.fajr: Icons.wb_twilight_rounded,
  PrayerName.dhuhr: Icons.wb_sunny_rounded,
  PrayerName.asr: Icons.wb_sunny_outlined,
  PrayerName.maghrib: Icons.nights_stay_rounded,
  PrayerName.isha: Icons.dark_mode_rounded,
};

extension PrayerTimesOrdered on PrayerTimes {
  List<MapEntry<PrayerName, DateTime>> get ordered => [
    MapEntry(PrayerName.fajr, fajr),
    MapEntry(PrayerName.dhuhr, dhuhr),
    MapEntry(PrayerName.asr, asr),
    MapEntry(PrayerName.maghrib, maghrib),
    MapEntry(PrayerName.isha, isha),
  ];

  /// The prayer whose window we're currently in, or null before Fajr.
  PrayerName? current(DateTime now) {
    PrayerName? c;
    for (final e in ordered) {
      if (!e.value.isAfter(now)) c = e.key;
    }
    return c;
  }
}

/// The hero sky follows the part of the day you're in.
class PrayerSky {
  final List<Color> colors;
  final double stars;
  const PrayerSky(this.colors, this.stars);

  static PrayerSky of(PrayerName? current) => switch (current) {
    null => const PrayerSky([Color(0xFF0B1B2B), Color(0xFF1C3550)], 1),
    PrayerName.fajr => const PrayerSky([
      Color(0xFF1E2F52),
      Color(0xFFB9765A),
    ], 0.5),
    PrayerName.dhuhr => const PrayerSky([
      Color(0xFF17607A),
      Color(0xFF3E97AB),
    ], 0),
    PrayerName.asr => const PrayerSky([
      Color(0xFF6B4A1A),
      Color(0xFFC08A2E),
    ], 0),
    PrayerName.maghrib => const PrayerSky([
      Color(0xFF34204A),
      Color(0xFFC85F3A),
    ], 0.35),
    PrayerName.isha => const PrayerSky([
      Color(0xFF0B1B2B),
      Color(0xFF1C3550),
    ], 1),
  };
}

String fmtClock(DateTime t) => DateFormat('h:mm a').format(t);

class PrayerHero extends ConsumerWidget {
  final PrayerTimes times;
  final ValueListenable<DateTime> now;
  const PrayerHero({super.key, required this.times, required this.now});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ValueListenableBuilder<DateTime>(
      valueListenable: now,
      builder: (context, t, _) {
        final current = times.current(t);
        final sky = PrayerSky.of(current);
        final next = times.nextPrayer(t);
        final remaining = next.value.difference(t);
        return AnimatedContainer(
          duration: context.motion.duration(AppMotion.value),
          curve: AppMotion.standard,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: sky.colors,
            ),
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(36.r)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              if (sky.stars > 0)
                Positioned.fill(
                  child: RepaintBoundary(
                    child: CustomPaint(painter: _StarsPainter(sky.stars)),
                  ),
                ),
              Positioned.fill(
                child: GeometricPattern(
                  color: Colors.white.withValues(alpha: 0.05),
                  cell: 56,
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  20.w,
                  MediaQuery.of(context).padding.top + 64.h,
                  20.w,
                  26.h,
                ),
                child: Column(
                  children: [
                    _dateBlock(t),
                    SizedBox(height: 10.h),
                    _locationChip(ref),
                    // SizedBox(height: 18.h),
                    _arc(context, t, next, remaining, current),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _dateBlock(DateTime t) {
    return Column(
      children: [
        Text(
          DateFormat('EEEE, d MMMM').format(t),
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ).slideIn(RevealDirection.top),
        SizedBox(height: 2.h),
        Text(
          times.hijriDate,
          style: TextStyle(
            fontSize: 13.sp,
            color: AppColors.goldLight,
            letterSpacing: 0.3,
          ),
        ).slideIn(
          RevealDirection.bottom,
          delay: const Duration(milliseconds: 70),
        ),
      ],
    );
  }

  Widget _locationChip(WidgetRef ref) {
    final label = ref.watch(currentLocationNameProvider).valueOrNull;
    String text = 'Locating…';
    var approx = false;
    if (label is LocationLabelResolved) {
      text = label.name;
      approx = label.isApproximate;
    } else if (label is LocationLabelUnavailable) {
      text = 'Location unavailable';
    }
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.location_on_rounded,
            size: 14.sp,
            color: AppColors.goldLight,
          ),
          SizedBox(width: 6.w),
          Flexible(
            child: Text(
              approx ? '$text (last known)' : text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12.sp, color: Colors.white),
            ),
          ),
        ],
      ),
    ).slideIn(
      RevealDirection.topEnd,
      delay: const Duration(milliseconds: 110),
      duration: AppMotion.normal,
    );
  }

  Widget _arc(
    BuildContext context,
    DateTime t,
    MapEntry<PrayerName, DateTime> next,
    Duration remaining,
    PrayerName? current,
  ) {
    final w = MediaQuery.of(context).size.width - 40.w;
    final h = w * 0.62;

    final start = times.fajr;
    final span = times.isha.difference(start).inSeconds.toDouble();
    double frac(DateTime x) =>
        span <= 0 ? 0 : (x.difference(start).inSeconds / span).clamp(0.0, 1.0);

    final marks = [for (final e in times.ordered) frac(e.value)];
    final passed = [for (final e in times.ordered) !e.value.isAfter(t)];

    return SizedBox(
      width: w,
      height: h,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _DayArcPainter(
                marks: marks,
                passed: passed,
                now: frac(t),
                gold: AppColors.gold,
                bg: PrayerSky.of(current).colors.last,
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.only(bottom: h * 0.01),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(height: 4.h),
                Text(
                  'NEXT PRAYER',
                  style: TextStyle(
                    fontSize: 10.sp,
                    letterSpacing: 2,
                    fontWeight: FontWeight.w700,
                    color: AppColors.goldLight,
                  ),
                ).slideIn(
                  RevealDirection.bottomStart,
                  delay: const Duration(milliseconds: 160),
                  distance: 14,
                ),

                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    AnimatedText(
                      prayerLabels[next.key]!,
                      style: TextStyle(
                        fontSize: 30.sp,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Directionality(
                      textDirection: TextDirection.rtl,
                      child: AnimatedText(
                        prayerArabic[next.key]!,
                        style: TextStyle(
                          fontFamily: 'AmiriQuran',
                          fontSize: 20.sp,
                          color: AppColors.goldLight,
                        ),
                      ),
                    ),
                  ],
                ).slideIn(
                  RevealDirection.topEnd,
                  delay: const Duration(milliseconds: 220),
                ),
                SizedBox(height: 4.h),
                Text(
                  _hms(remaining),
                  style: TextStyle(
                    fontSize: 38.sp,
                    fontWeight: FontWeight.w300,
                    letterSpacing: 2,
                    color: Colors.white,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                SizedBox(height: 2.h),
                AnimatedText(
                  'at ${fmtClock(next.value)}',
                  style: TextStyle(
                    fontSize: 13.sp,
                    color: Colors.white.withValues(alpha: 0.75),
                  ),
                ).slideIn(
                  RevealDirection.bottom,
                  delay: const Duration(milliseconds: 300),
                  duration: AppMotion.normal,
                  distance: 14,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _hms(Duration d) {
    final s = d.isNegative ? 0 : d.inSeconds;
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(s ~/ 3600)}:${two((s % 3600) ~/ 60)}:${two(s % 60)}';
  }
}

class _DayArcPainter extends CustomPainter {
  final List<double> marks;
  final List<bool> passed;
  final double now;
  final Color gold;
  final Color bg;

  const _DayArcPainter({
    required this.marks,
    required this.passed,
    required this.now,
    required this.gold,
    required this.bg,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.96);
    final r = size.width / 2 - 14;
    final rect = Rect.fromCircle(center: center, radius: r);

    Offset at(double f) {
      final a = math.pi + f * math.pi;
      return Offset(center.dx + r * math.cos(a), center.dy + r * math.sin(a));
    }

    canvas.drawArc(
      rect,
      math.pi,
      math.pi,
      false,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawArc(
      rect,
      math.pi,
      math.pi * now,
      false,
      Paint()
        ..color = gold
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round,
    );

    for (var i = 0; i < marks.length; i++) {
      final p = at(marks[i]);
      canvas.drawCircle(p, 7, Paint()..color = bg);
      canvas.drawCircle(
        p,
        5,
        Paint()
          ..color = passed[i] ? gold : Colors.white
          ..style = passed[i] ? PaintingStyle.fill : PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }

    final n = at(now);
    canvas.drawCircle(
      n,
      18,
      Paint()
        ..shader = RadialGradient(
          colors: [gold.withValues(alpha: 0.6), Colors.transparent],
        ).createShader(Rect.fromCircle(center: n, radius: 18)),
    );
    canvas.drawCircle(n, 8, Paint()..color = const Color(0xFFFFE08A));
  }

  @override
  bool shouldRepaint(_DayArcPainter old) =>
      old.now != now || !listEquals(old.passed, passed) || old.bg != bg;
}

class _StarsPainter extends CustomPainter {
  final double intensity;
  const _StarsPainter(this.intensity);

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(7);
    final p = Paint();
    for (var i = 0; i < 46; i++) {
      final x = rnd.nextDouble() * size.width;
      final y = rnd.nextDouble() * size.height * 0.75;
      final r = 0.5 + rnd.nextDouble() * 1.3;
      p.color = Colors.white.withValues(
        alpha: (0.25 + rnd.nextDouble() * 0.6) * intensity,
      );
      canvas.drawCircle(Offset(x, y), r, p);
    }
  }

  @override
  bool shouldRepaint(_StarsPainter old) => old.intensity != intensity;
}
