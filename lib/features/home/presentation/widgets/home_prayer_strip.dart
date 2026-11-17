import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/motion/motion.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/islamic_ornaments.dart';
import '../../../auth/presentation/providers/auth_session_provider.dart';
import '../../../prayer_logs/domain/current_prayer.dart';
import '../../../prayer_logs/domain/day_prayers.dart';
import '../../../prayer_logs/domain/prayer_log.dart';
import '../../../prayer_logs/presentation/prayer_labels.dart';
import '../../../prayer_logs/presentation/providers/prayer_logs_providers.dart';
import '../../../prayer_times/domain/entities/prayer_times.dart';
import '../../../prayer_times/presentation/providers/prayer_times_provider.dart';
import '../../../snaps/presentation/providers/snap_providers.dart';
import '../../../snaps/presentation/snap_entry.dart';

/// Today's five prayers on Home, in the hero style of the app's other
/// headers: a compact dark card with the geometric pattern, each prayer's name
/// and time, and a circle that says where it stands:
///
/// - **orange with a white tick**: logged;
/// - **red with a white dash**: its time closed and nothing was logged;
/// - **a camera, gently pulsing**: its snap time is open now and it is not
///   logged yet. Tapping it does exactly what the Camera tab in the bottom
///   bar does ([openSnapFromNav]);
/// - **a dashed circle**: still to come.
///
/// Everything comes from the real prayer schedule, the server's answer about
/// the open prayer, and today's logs. Tapping the rest of the card opens the
/// day view. Not shown to guests (nothing to log without an account).
class HomePrayerStrip extends ConsumerStatefulWidget {
  const HomePrayerStrip({super.key});

  @override
  ConsumerState<HomePrayerStrip> createState() => _HomePrayerStripState();
}

class _HomePrayerStripState extends ConsumerState<HomePrayerStrip>
    with WidgetsBindingObserver {
  Timer? _ticker;

  /// Server clock minus device clock, so the window edges follow the server
  /// even if the phone's clock is off.
  Duration _skew = Duration.zero;
  CurrentPrayerState? _seen;
  bool _refreshRequested = false;

  DateTime get _now => DateTime.now().add(_skew);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ticker = Timer.periodic(const Duration(seconds: 5), (_) => _tick());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  void _refresh() {
    _refreshRequested = true;
    ref.read(currentPrayerProvider.notifier).refresh();
    ref.invalidate(prayerLogsProvider);
  }

  /// A prayer window just opened or closed: ask the server what is open now,
  /// once, so the camera moves to the right prayer.
  void _tick() {
    if (!mounted) return;
    final s = ref.read(currentPrayerProvider).valueOrNull;
    if (s == null) return;
    final boundary = s.current?.endsAt ?? s.next?.startsAt;
    if (boundary != null && !_now.isBefore(boundary) && !_refreshRequested) {
      _refresh();
    }
    // The clock moved: a window that just closed turns its circle red now.
    setState(() {});
  }

  void _track(CurrentPrayerState s) {
    if (!identical(s, _seen)) {
      _seen = s;
      _skew = s.now.difference(DateTime.now());
      _refreshRequested = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(authSessionProvider).isAuthenticated) {
      return const SizedBox.shrink();
    }
    final state = ref.watch(currentPrayerProvider).valueOrNull;
    if (state != null) _track(state);
    final open = state?.current;
    final logs =
        ref.watch(prayerLogsProvider(null)).valueOrNull ?? const <PrayerLog>[];
    final times = ref.watch(prayerTimesNotifierProvider).valueOrNull;
    final now = _now;

    final done = {
      for (final l in logs) l.prayer,
      if (open != null && open.logged) open.prayer,
    };
    final days = dayPrayers(done: done, window: state, now: now);

    // The prayer whose snap time is open right now and not logged yet.
    final active = open != null && !open.logged && now.isBefore(open.endsAt)
        ? open.prayer
        : null;
    // Pulses only while a snap can really be sent; otherwise the camera is
    // still there (it explains why when tapped) but still.
    final canSnap = ref.watch(snapAvailabilityProvider).isAvailable;

    return Padding(
      padding: EdgeInsets.only(bottom: 22.h),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: AppColors.heroGradient,
          ),
          borderRadius: BorderRadius.circular(30.r),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: GeometricPattern(
                color: AppColors.goldLight.withValues(alpha: 0.08),
                cell: 52,
              ),
            ),
            Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: () => context.push('/prayer-log'),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(10.w, 12.h, 10.w, 12.h),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          for (final (i, p) in PrayerName.values.indexed)
                            Expanded(
                              child: _PrayerSlot(
                                prayer: p,
                                time: times == null ? null : _timeOf(times, p),
                                status: switch (days[i]) {
                                  DayPrayer.logged => _Status.done,
                                  _ when active == p => _Status.open,
                                  DayPrayer.missed => _Status.missed,
                                  DayPrayer.pending => _Status.idle,
                                },
                                pulse: canSnap,
                                onCamera: () => openSnapFromNav(context, ref),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static DateTime _timeOf(PrayerTimes t, PrayerName p) => switch (p) {
    PrayerName.fajr => t.fajr,
    PrayerName.dhuhr => t.dhuhr,
    PrayerName.asr => t.asr,
    PrayerName.maghrib => t.maghrib,
    PrayerName.isha => t.isha,
  };
}

enum _Status { done, missed, open, idle }

class _PrayerSlot extends StatelessWidget {
  final PrayerName prayer;
  final DateTime? time;
  final _Status status;

  /// Whether the camera pulses (when this slot is the open one).
  final bool pulse;
  final VoidCallback onCamera;

  const _PrayerSlot({
    required this.prayer,
    required this.time,
    required this.status,
    required this.pulse,
    required this.onCamera,
  });

  @override
  Widget build(BuildContext context) {
    final size = 42.w;
    final accent = AppColors.emeraldInk;

    final Widget circle = switch (status) {
      _Status.done => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: accent),
        child: Icon(Icons.check_rounded, size: 24.sp, color: Colors.white),
      ),
      _Status.missed => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.error,
        ),
        child: Icon(Icons.remove_rounded, size: 24.sp, color: Colors.white),
      ),
      _Status.open => _CameraCue(size: size, animate: pulse, onTap: onCamera),
      _Status.idle => CustomPaint(
        size: Size.square(size),
        painter: _DashedCirclePainter(Colors.white.withValues(alpha: 0.45)),
      ),
    };

    final label = switch (status) {
      _Status.done => 'logged',
      _Status.missed => 'missed',
      _Status.open => 'open, tap to send a snap',
      _Status.idle => 'not yet',
    };
    final isOpen = status == _Status.open;

    return Semantics(
      label: '${prayer.label} $label',
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Room for the camera's pulse, which spreads past the circle.
          SizedBox(
            width: size + 8.w,
            height: size + 8.w,
            child: Center(child: circle),
          ),
          SizedBox(height: 2.h),
          // Shrink rather than wrap, so a long name or a large text size keeps
          // the five slots in line.
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              prayer.label,
              maxLines: 1,
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: isOpen ? FontWeight.w800 : FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
          SizedBox(height: 2.h),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              time == null ? '—' : clockTime(time!),
              maxLines: 1,
              style: TextStyle(
                fontSize: 11.5.sp,
                fontWeight: FontWeight.w600,
                color: isOpen
                    ? AppColors.goldLight
                    : Colors.white.withValues(alpha: 0.78),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The camera on the prayer whose snap time is open: a ring that breathes out
/// and fades, and a small bounce of the icon, once every couple of seconds.
/// Subtle, and enough to draw the eye. Still under reduced motion, or when a
/// snap can't be sent right now ([animate] false).
class _CameraCue extends StatefulWidget {
  final double size;
  final bool animate;
  final VoidCallback onTap;
  const _CameraCue({
    required this.size,
    required this.animate,
    required this.onTap,
  });

  @override
  State<_CameraCue> createState() => _CameraCueState();
}

class _CameraCueState extends State<_CameraCue>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );

  bool get _running => widget.animate && !context.motion.reduced;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(_CameraCue old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    if (_running) {
      if (!_c.isAnimating) _c.repeat();
    } else {
      _c.stop();
      _c.value = 0;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  /// A ring that grows to 1.7x and fades, starting [delay] into the cycle.
  Widget _ring(double t, double delay) {
    final p = ((t - delay) / 0.55).clamp(0.0, 1.0);
    if (p == 0 || p == 1) return const SizedBox.shrink();
    final eased = Curves.easeOut.transform(p);
    return Opacity(
      opacity: 0.55 * (1 - eased),
      child: Container(
        width: widget.size * (1 + 0.7 * eased),
        height: widget.size * (1 + 0.7 * eased),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.emeraldInk, width: 2),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.emeraldInk;
    final size = widget.size;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      child: SizedBox(
        width: size,
        height: size,
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final t = _c.value;
            // A short bounce at the start of each cycle.
            final bounce = t < 0.3 ? math.sin(math.pi * t / 0.3) : 0.0;
            final scale = 1 + 0.1 * bounce;
            return Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                if (_running) ...[_ring(t, 0), _ring(t, 0.22)],
                Transform.scale(
                  scale: scale,
                  child: Container(
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.14),
                      border: Border.all(color: accent, width: 2),
                    ),
                    child: Icon(
                      Icons.photo_camera_rounded,
                      size: 22.sp,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _DashedCirclePainter extends CustomPainter {
  final Color color;
  _DashedCirclePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    final radius = size.width / 2 - 1;
    final center = size.center(Offset.zero);
    const dashes = 14;
    const sweep = 2 * math.pi / dashes;
    for (var i = 0; i < dashes; i++) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        i * sweep,
        sweep * 0.55,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DashedCirclePainter old) => old.color != color;
}
