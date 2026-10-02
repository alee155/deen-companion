import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/motion/motion.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/failure_view.dart';
import '../../../../shared/widgets/islamic_ornaments.dart';
import '../../domain/entities/qibla_info.dart';
import '../providers/qibla_providers.dart';
import '../utils/qibla_math.dart';
import '../widgets/qibla_dial.dart';
import '../widgets/qibla_info_widgets.dart';
import '../widgets/qibla_radar.dart';

class QiblaScreen extends ConsumerStatefulWidget {
  const QiblaScreen({super.key});

  @override
  ConsumerState<QiblaScreen> createState() => _QiblaScreenState();
}

class _QiblaScreenState extends ConsumerState<QiblaScreen> {
  bool _wasMatched = false;
  bool _timedOutWaitingForCompass = false;
  Timer? _waitTimer;

  // Once the needle matches the Qibla direction, the display freezes at that
  // snapshot instead of following the (inevitably jittery) live compass. The
  // user taps "Recheck" to resume live tracking — a deliberate product
  // decision: once you've found the Qibla, sensor noise shouldn't keep
  // nudging the dial around.
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
    AppHaptics.tap();
    setState(() {
      _isLocked = false;
      _wasMatched = false;
    });
  }

  @override
  void initState() {
    super.initState();
    // If no heading has arrived within a few seconds the device likely has no
    // magnetometer (or compass access is blocked) — stop showing a spinner
    // and offer the numeric-bearing fallback instead.
    _waitTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _timedOutWaitingForCompass = true);
    });
  }

  @override
  void dispose() {
    _waitTimer?.cancel();
    super.dispose();
  }

  Future<void> _showCalibrationTip() {
    return showDialog(
      animationStyle: AppMotion.dialogStyle,
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceLight,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: Icon(Icons.explore_rounded, color: AppColors.emeraldInk),
        title: const Text('Calibrate your compass'),
        content: const Text(
          'If the dial seems off, move your phone in a slow figure-8 '
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

  void _refresh() {
    AppHaptics.tap();
    _unlock();
    ref.read(qiblaNotifierProvider.notifier).refresh();
  }

  @override
  Widget build(BuildContext context) {
    final qiblaAsync = ref.watch(qiblaNotifierProvider);
    // The dial's box includes room for ripples, so size it from what's left.
    final dialSize =
        ((MediaQuery.sizeOf(context).width - 48.w) / qiblaDialRippleScale)
            .clamp(230.0, 330.0);

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.backgroundGradientStart,
              AppColors.backgroundGradientEnd,
            ],
          ),
        ),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: qiblaAsync.when(
            loading: () => _layout(
              dialSize: dialSize,
              stage: _radar(dialSize, 'Locating the Kaaba…'),
              body: const [],
            ),
            error: (error, _) => _layout(
              dialSize: dialSize,
              stage: _radar(dialSize, 'Something went wrong'),
              body: [
                FailureView(
                  failure: failureFrom(error),
                  onRetry: () =>
                      ref.read(qiblaNotifierProvider.notifier).refresh(),
                ),
              ],
            ),
            // Only this subtree watches the high-frequency compass stream.
            data: (qibla) => Consumer(
              builder: (context, ref, _) => _compassBody(ref, qibla, dialSize),
            ),
          ),
        ),
      ),
    );
  }

  // Same footprint as the dial so the layout doesn't jump when it takes over.
  Widget _radar(double dialSize, String label) => SizedBox(
    width: dialSize * qiblaDialRippleScale,
    height: dialSize * qiblaDialRippleScale,
    child: Center(
      child: QiblaRadar(size: dialSize, label: label),
    ),
  );

  Widget _compassBody(WidgetRef ref, QiblaInfo qibla, double dialSize) {
    final qiblaDirection = qibla.qiblaDirection;
    final distanceKm = qibla.distanceKm;

    // Magnetic → true north correction; the Qibla bearing is true-north
    // based while the sensor is magnetic. Falls back to 0 until resolved.
    final declination = ref.watch(magneticDeclinationProvider).value ?? 0.0;

    if (_isLocked) {
      return _active(
        dialSize: dialSize,
        qiblaDirection: _lockedQiblaDirection!,
        distanceKm: _lockedDistanceKm!,
        trueHeading: _lockedTrueHeading!,
        diff: _lockedDiff!,
        aligned: true,
        lowAccuracy: false,
      );
    }

    final reading = ref.watch(compassHeadingProvider).value;
    final magneticHeading = reading?.heading;

    if (magneticHeading == null) {
      if (!_timedOutWaitingForCompass) {
        return _layout(
          dialSize: dialSize,
          stage: _radar(dialSize, 'Waiting for compass sensor…'),
          body: const [],
        );
      }
      return _unavailable(dialSize, qiblaDirection, distanceKm);
    }

    // A real reading arrived — don't flash the fallback afterwards.
    _waitTimer?.cancel();

    final trueHeading = normalizeDegrees(magneticHeading + declination);
    final diff = shortestAngleDiff(qiblaDirection, trueHeading);
    final aligned = diff.abs() <= qiblaMatchToleranceDegrees;

    if (aligned && !_wasMatched) {
      _wasMatched = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _lockOnto(
          qiblaDirection: qiblaDirection,
          distanceKm: distanceKm,
          trueHeading: trueHeading,
          diff: diff,
        );
      });
    }

    return _active(
      dialSize: dialSize,
      qiblaDirection: qiblaDirection,
      distanceKm: distanceKm,
      trueHeading: trueHeading,
      diff: diff,
      aligned: aligned,
      lowAccuracy: isLowCompassAccuracy(reading?.accuracy),
    );
  }

  Widget _active({
    required double dialSize,
    required double qiblaDirection,
    required double distanceKm,
    required double trueHeading,
    required double diff,
    required bool aligned,
    required bool lowAccuracy,
  }) {
    return _layout(
      dialSize: dialSize,
      stage: QiblaDial(
        heading: trueHeading,
        qiblaDirection: qiblaDirection,
        aligned: aligned,
        locked: _isLocked,
        size: dialSize,
      ),
      body: [
        if (lowAccuracy)
          QiblaNoticeCard(
            icon: Icons.explore_off_rounded,
            warning: true,
            text:
                'Your compass sensor looks uncalibrated — tap for a quick fix.',
            onTap: _showCalibrationTip,
          ).appear(),
        QiblaStatusCard(
          diff: diff,
          aligned: aligned,
          locked: _isLocked,
          onRecheck: _unlock,
        ).appear(delay: const Duration(milliseconds: 80)),
        _stats(
          qiblaDirection: qiblaDirection,
          distanceKm: distanceKm,
          heading: trueHeading,
          aligned: aligned,
        ).appear(delay: const Duration(milliseconds: 140)),
        const QiblaNoticeCard(
          icon: Icons.phone_android_rounded,
          text:
              'Hold your phone flat and keep it away from metal, magnets '
              'and speakers for the most accurate reading.',
        ).appear(delay: const Duration(milliseconds: 200)),
      ],
    );
  }

  Widget _unavailable(double dialSize, double qiblaDirection, double km) {
    return _layout(
      dialSize: dialSize,
      stage: QiblaDial(
        heading: null,
        qiblaDirection: qiblaDirection,
        aligned: false,
        size: dialSize,
      ),
      body: [
        const QiblaNoticeCard(
          icon: Icons.explore_off_rounded,
          warning: true,
          text:
              "We couldn't get a reading from your device's compass. It may "
              'lack a magnetometer or its access is restricted.',
        ).appear(),
        QiblaStatusCard(
          diff: null,
          aligned: false,
          locked: false,
          onRecheck: _unlock,
        ).appear(delay: const Duration(milliseconds: 80)),
        _stats(
          qiblaDirection: qiblaDirection,
          distanceKm: km,
          heading: null,
          aligned: false,
        ).appear(delay: const Duration(milliseconds: 140)),
      ],
    );
  }

  Widget _stats({
    required double qiblaDirection,
    required double distanceKm,
    required double? heading,
    required bool aligned,
  }) {
    return Row(
      children: [
        Expanded(
          child: QiblaStatTile(
            icon: Icons.mosque_rounded,
            label: 'Qibla',
            value: '${qiblaDirection.round()}°',
            caption: compassLabel(qiblaDirection),
            highlight: aligned,
          ),
        ),
        SizedBox(width: 10.w),
        Expanded(
          child: QiblaStatTile(
            icon: Icons.navigation_rounded,
            label: 'Facing',
            value: heading == null ? '--' : '${heading.round()}°',
            caption: heading == null ? null : compassLabel(heading),
          ),
        ),
        SizedBox(width: 10.w),
        Expanded(
          child: QiblaStatTile(
            icon: Icons.straighten_rounded,
            label: 'To Kaaba',
            value: '${_grouped(distanceKm.round())} km',
          ),
        ),
      ],
    );
  }

  String _grouped(int n) => n.toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ',',
  );

  /// Dark hero holding the dial, then the info cards on the parchment.
  Widget _layout({
    required double dialSize,
    required Widget stage,
    required List<Widget> body,
  }) {
    return Column(
      children: [
        _hero(dialSize, stage),
        Padding(
          padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 28.h),
          child: Column(
            children: [
              for (var i = 0; i < body.length; i++) ...[
                if (i > 0) SizedBox(height: 12.h),
                body[i],
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _hero(double dialSize, Widget stage) {
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.heroSurface, AppColors.emeraldInkDark],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(36.r)),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: GeometricPattern(
              color: AppColors.goldLight.withValues(alpha: 0.07),
              cell: 52,
            ),
          ),
          Positioned(
            right: -30.w,
            top: 60.h,
            child: Icon(
              Icons.mosque_rounded,
              size: 190.sp,
              color: AppColors.gold.withValues(alpha: 0.08),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              20.w,
              MediaQuery.paddingOf(context).top + 8.h,
              20.w,
              28.h,
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    GlassIconButton(
                      icon: Icons.arrow_back_rounded,
                      tooltip: 'Back',
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                    const Spacer(),
                    GlassIconButton(
                      icon: Icons.explore_outlined,
                      tooltip: 'Compass seems off?',
                      onPressed: _showCalibrationTip,
                    ),
                    SizedBox(width: 8.w),
                    GlassIconButton(
                      icon: Icons.refresh_rounded,
                      tooltip: 'Refresh',
                      onPressed: _refresh,
                    ),
                  ],
                ),
                SizedBox(height: 6.h),
                Text(
                  'Qibla Finder',
                  style: TextStyle(
                    fontSize: 28.sp,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ).slideIn(RevealDirection.top),
                SizedBox(height: 4.h),
                Text(
                  'Line the Kaaba up with the marker at the top',
                  style: TextStyle(
                    fontSize: 13.sp,
                    color: AppColors.onHeroSurface.withValues(alpha: 0.75),
                  ),
                ).slideIn(
                  RevealDirection.top,
                  delay: const Duration(milliseconds: 70),
                ),
                SizedBox(height: 26.h),
                stage,
              ],
            ),
          ),
        ],
      ),
    );
  }
}
