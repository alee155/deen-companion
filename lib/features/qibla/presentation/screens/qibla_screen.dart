import 'dart:async';
import 'dart:math' as math;
import 'package:deen_companion/features/ads/presentation/widgets/banner_ad_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/failure_view.dart';
import '../providers/qibla_providers.dart';
import '../widgets/qibla_compass_painter.dart';

const double _matchToleranceDegrees = 6;
const _needleTop = Color(0xFFFFD9A0);

// Sensor accuracy is in degrees, lower is better. Some platforms signal
// "unreliable" as a negative value rather than a large positive one, so
// both are treated as "needs calibration." Null (no signal reported at
// all) is deliberately not flagged — that's "unknown," not "bad."
bool _isLowAccuracy(double? accuracy) {
  if (accuracy == null) return false;
  return accuracy < 0 || accuracy > 25;
}

// Getters, not constants: these follow the active Light/Dark palette.
Color get _needleBottom => AppColors.amber;
Color get _bgTop => AppColors.backgroundGradientStart;
Color get _bgBottom => AppColors.backgroundGradientEnd;

class QiblaScreen extends ConsumerStatefulWidget {
  const QiblaScreen({super.key});

  @override
  ConsumerState<QiblaScreen> createState() => _QiblaScreenState();
}

class _QiblaScreenState extends ConsumerState<QiblaScreen> {
  bool _wasMatched = false;
  bool _timedOutWaitingForCompass = false;
  Timer? _waitTimer;

  // Once the needle matches the Qibla direction, we freeze the display
  // entirely at that snapshot instead of continuing to follow the live
  // (and inevitably slightly jittery) compass stream. The user has to
  // explicitly tap "Recheck" to resume live tracking. This is a
  // deliberate product decision: once you've found the Qibla, further
  // sensor noise shouldn't make the needle keep drifting around.
  bool _isLocked = false;
  double? _lockedQiblaDirection;
  double? _lockedDistanceKm;
  double? _lockedTrueHeading;
  double? _lockedDiff;

  void _lockOnto({
    required double qiblaDirection,
    required double distanceKm,
    required double trueHeading,
    required double diff,
  }) {
    setState(() {
      _isLocked = true;
      _lockedQiblaDirection = qiblaDirection;
      _lockedDistanceKm = distanceKm;
      _lockedTrueHeading = trueHeading;
      _lockedDiff = diff;
    });
    HapticFeedback.heavyImpact();
  }

  void _unlock() {
    setState(() {
      _isLocked = false;
      _wasMatched = false;
    });
  }

  @override
  void initState() {
    super.initState();
    // If no heading has arrived within a few seconds, the device likely
    // has no magnetometer (or compass access is blocked) — stop showing
    // an indefinite spinner and offer the numeric-bearing fallback
    // instead. A genuinely working compass reports its first reading
    // almost immediately, so this window is generous, not tight.
    _waitTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _timedOutWaitingForCompass = true);
    });
  }

  @override
  void dispose() {
    _waitTimer?.cancel();
    super.dispose();
  }

  Future<void> _showCalibrationTip(BuildContext context) {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceLight,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Calibrate your compass'),
        content: const Text(
          'If the needle seems off, move your phone in a slow figure-8 '
          'motion a few times, away from metal objects, magnets, or '
          'speakers — these can all throw off the reading.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  double _shortestAngleDiff(double target, double current) {
    double diff = (target - current) % 360;
    if (diff < -180) diff += 360;
    if (diff > 180) diff -= 360;
    return diff;
  }

  @override
  Widget build(BuildContext context) {
    final qiblaAsync = ref.watch(qiblaNotifierProvider);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_bgTop, _bgBottom],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                    Text(
                      'QIBLA FINDER',
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: AppColors.inkText,
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.explore_outlined),
                          tooltip: 'Compass seems off?',
                          onPressed: () => _showCalibrationTip(context),
                        ),
                        IconButton(
                          icon: const Icon(Icons.refresh),
                          onPressed: () {
                            _unlock();
                            ref.read(qiblaNotifierProvider.notifier).refresh();
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: qiblaAsync.when(
                  // Only this subtree watches the high-frequency compass
                  // stream, so the header/background above never rebuilds
                  // on sensor ticks.
                  data: (qibla) => RepaintBoundary(
                    child: Consumer(
                      builder: (context, ref, _) {
                        // Best-effort correction from magnetic to true
                        // north — read as a plain .value rather than
                        // .when()'d, so the compass shows *a* reading
                        // immediately using the safe 0.0 fallback while
                        // this resolves, rather than blocking on it. In
                        // practice it resolves within a frame or two,
                        // since it's a local computation, not a network
                        // call.
                        final declination =
                            ref.watch(magneticDeclinationProvider).value ?? 0.0;

                        // Locked — show the frozen snapshot, completely
                        // ignoring whatever the live compass is doing.
                        if (_isLocked) {
                          return _compassContent(
                            _lockedQiblaDirection!,
                            _lockedDistanceKm!,
                            _lockedTrueHeading!,
                            _lockedDiff!,
                            true,
                            isLocked: true,
                            onUnlock: _unlock,
                            showCalibrationBanner: false,
                          );
                        }

                        final readingAsync = ref.watch(compassHeadingProvider);
                        return readingAsync.when(
                          data: (reading) {
                            final magneticHeading = reading.heading;
                            if (magneticHeading == null) {
                              return _timedOutWaitingForCompass
                                  ? _compassUnavailableState(
                                      qibla.qiblaDirection,
                                    )
                                  : _waitingState();
                            }

                            // A real reading arrived — stop the "maybe
                            // this device has no compass" timer so we
                            // don't flash the fallback UI afterwards.
                            _waitTimer?.cancel();

                            // The correction that actually matters: the
                            // Qibla bearing is true-north-based, the raw
                            // sensor heading is magnetic-north-based.
                            // Without this line the needle is off by
                            // whatever the local declination is —
                            // sometimes negligible, sometimes several
                            // degrees or more, depending on where in the
                            // world the phone is.
                            var trueHeading =
                                (magneticHeading + declination) % 360;
                            if (trueHeading < 0) trueHeading += 360;

                            final diff = _shortestAngleDiff(
                              qibla.qiblaDirection,
                              trueHeading,
                            );
                            final isMatched =
                                diff.abs() <= _matchToleranceDegrees;

                            if (isMatched && !_wasMatched) {
                              _wasMatched = true;
                              // Freeze right here at the moment of match,
                              // rather than one more frame later.
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (!mounted) return;
                                _lockOnto(
                                  qiblaDirection: qibla.qiblaDirection,
                                  distanceKm: qibla.distanceKm,
                                  trueHeading: trueHeading,
                                  diff: diff,
                                );
                              });
                            }

                            return _compassContent(
                              qibla.qiblaDirection,
                              qibla.distanceKm,
                              trueHeading,
                              diff,
                              isMatched,
                              isLocked: false,
                              onUnlock: _unlock,
                              showCalibrationBanner: _isLowAccuracy(
                                reading.accuracy,
                              ),
                            );
                          },
                          loading: _waitingState,
                          error: (_, __) => _waitingState(),
                        );
                      },
                    ),
                  ),
                  loading: () => Center(
                    child: CircularProgressIndicator(color: AppColors.gold),
                  ),
                  error: (error, _) => _errorState(error),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _compassContent(
    double qiblaDirection,
    double distanceKm,
    double trueHeading,
    double diff,
    bool isMatched, {
    required bool isLocked,
    required VoidCallback onUnlock,
    required bool showCalibrationBanner,
  }) {
    return Column(
      children: [
        if (showCalibrationBanner) _calibrationBanner(),
        SizedBox(height: 12.h),
        SizedBox(
          height: 300.h,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Rotating ring — real compass card behavior. Rotated by
              // the *corrected* heading, since the ring's N/E/S/W labels
              // are meant to mark true geographic directions, matching
              // the same reference frame the Qibla bearing itself uses.
              Transform.rotate(
                angle: -trueHeading * math.pi / 180,
                child: CustomPaint(
                  size: Size(260.w, 260.w),
                  painter: QiblaRingPainter(
                    ringColor: AppColors.gold.withValues(alpha: 0.5),
                    labelColor: AppColors.inkText,
                    dotColor: AppColors.textMuted,
                  ),
                ),
              ),
              // Needle — rotates to always point at Qibla relative to current facing.
              Transform.rotate(
                angle: diff * math.pi / 180,
                child: _needle(isMatched),
              ),
              // Fixed target marker — Kaaba icon, never rotates.
              Positioned(top: 4.h, child: _kaabaMarker()),
            ],
          ),
        ),
        SizedBox(height: 16.h),
        Text(
          '${qiblaDirection.round()}°',
          style: TextStyle(
            fontSize: 40.sp,
            fontWeight: FontWeight.w700,
            color: AppColors.inkText,
          ),
        ),
        Text(
          'Device\'s angle to qibla',
          style: TextStyle(fontSize: 13.sp, color: AppColors.textSecondary),
        ),
        const BannerAdWidget(margin: EdgeInsets.symmetric(vertical: 4)),

        GestureDetector(
          onTap: isLocked ? onUnlock : null,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
            decoration: BoxDecoration(
              color: isMatched
                  ? AppColors.emeraldInk.withValues(alpha: 0.12)
                  : Colors.white.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(30.r),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isLocked) ...[
                  Icon(
                    Icons.lock_outline,
                    size: 15.sp,
                    color: AppColors.emeraldInk,
                  ),
                  SizedBox(width: 6.w),
                ],
                Text(
                  isLocked
                      ? 'Locked onto Qibla — tap to recheck'
                      : (isMatched
                            ? 'You\'re facing the Qibla'
                            : 'Rotate the phone ${diff.abs().round()}° to the ${diff > 0 ? 'right' : 'left'}'),
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w500,
                    color: isMatched ? AppColors.emeraldInk : AppColors.inkText,
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: 16.h),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.w),
          child: Text(
            'Distance to Kaaba: ${distanceKm.toStringAsFixed(0)} km',
            style: TextStyle(fontSize: 12.sp, color: AppColors.textMuted),
          ),
        ),
        const Spacer(),
      ],
    );
  }

  Widget _calibrationBanner() {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 0),
      child: GestureDetector(
        onTap: () => _showCalibrationTip(context),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
          decoration: BoxDecoration(
            color: AppColors.gold.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
          ),
          child: Row(
            children: [
              Icon(
                Icons.explore_off_outlined,
                size: 16.sp,
                color: AppColors.gold,
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  'Your compass sensor looks uncalibrated — tap for a quick fix',
                  style: TextStyle(fontSize: 12.sp, color: AppColors.inkText),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _needle(bool isMatched) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CustomPaint(
          size: Size(28.w, 90.h),
          painter: _TeardropPainter(
            color: isMatched ? AppColors.emeraldInk : _needleTop,
          ),
        ),
        Transform.translate(
          offset: Offset(0, -6.h),
          child: Container(
            width: 34.w,
            height: 34.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isMatched
                    ? [AppColors.emeraldInk, AppColors.emeraldInkDark]
                    : [_needleTop, _needleBottom],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _kaabaMarker() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.arrow_drop_down, size: 30.sp, color: AppColors.gold),
        Transform.translate(
          offset: Offset(0, -8.h),
          child: Container(
            width: 36.w,
            height: 36.w,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            padding: EdgeInsets.all(7.w),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF2B2B2B),
                borderRadius: BorderRadius.circular(3.r),
              ),
              child: Align(
                alignment: Alignment.topCenter,
                child: Container(height: 4.h, color: AppColors.gold),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _waitingState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(20.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppColors.gold),
            SizedBox(height: 16.h),
            Text(
              'Waiting for compass sensor…',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13.sp),
            ),
          ],
        ),
      ),
    );
  }

  Widget _compassUnavailableState(double qiblaDirection) {
    final compassDirection = _compassLabel(qiblaDirection);
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.explore_off_outlined,
              size: 40.sp,
              color: AppColors.gold,
            ),
            SizedBox(height: 16.h),
            Text(
              "We couldn't get a reading from your device's compass",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15.sp,
                color: AppColors.inkText,
              ),
            ),
            SizedBox(height: 10.h),
            Text(
              'This can happen if your phone lacks a magnetometer or its '
              'access is restricted. You can still orient yourself using '
              'the direction below with any other compass, or the sun.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13.sp),
            ),
            SizedBox(height: 20.h),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 14.h),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(20.r),
              ),
              child: Column(
                children: [
                  Text(
                    '${qiblaDirection.round()}° $compassDirection',
                    style: TextStyle(
                      fontSize: 28.sp,
                      fontWeight: FontWeight.w700,
                      color: AppColors.inkText,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    'from true north',
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _compassLabel(double degrees) {
    const labels = [
      'N',
      'NNE',
      'NE',
      'ENE',
      'E',
      'ESE',
      'SE',
      'SSE',
      'S',
      'SSW',
      'SW',
      'WSW',
      'W',
      'WNW',
      'NW',
      'NNW',
    ];
    final index = ((degrees % 360) / 22.5).round() % 16;
    return labels[index];
  }

  Widget _errorState(Object error) {
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(20.w),
        child: FailureView(
          failure: failureFrom(error),
          onRetry: () => ref.read(qiblaNotifierProvider.notifier).refresh(),
        ),
      ),
    );
  }
}

class _TeardropPainter extends CustomPainter {
  final Color color;
  const _TeardropPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width / 2, 0)
      ..quadraticBezierTo(
        size.width,
        size.height * 0.7,
        size.width / 2,
        size.height,
      )
      ..quadraticBezierTo(0, size.height * 0.7, size.width / 2, 0)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _TeardropPainter oldDelegate) =>
      oldDelegate.color != color;
}
