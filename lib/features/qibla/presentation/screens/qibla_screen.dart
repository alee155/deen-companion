import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../providers/qibla_providers.dart';
import '../widgets/qibla_compass_painter.dart';

const double _matchToleranceDegrees = 6;
const _needleTop = Color(0xFFFFD9A0);
const _needleBottom = Color(0xFFE8823C);
const _bgTop = Color(0xFFFDF8F0);
const _bgBottom = Color(0xFFF3E2C8);

class QiblaScreen extends ConsumerStatefulWidget {
  const QiblaScreen({super.key});

  @override
  ConsumerState<QiblaScreen> createState() => _QiblaScreenState();
}

class _QiblaScreenState extends ConsumerState<QiblaScreen> {
  bool _wasMatched = false;

  double _shortestAngleDiff(double target, double current) {
    double diff = (target - current) % 360;
    if (diff < -180) diff += 360;
    if (diff > 180) diff -= 360;
    return diff;
  }

  @override
  Widget build(BuildContext context) {
    final qiblaAsync = ref.watch(qiblaNotifierProvider);
    final compassAsync = ref.watch(compassEventProvider);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
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
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: () =>
                          ref.read(qiblaNotifierProvider.notifier).refresh(),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: qiblaAsync.when(
                  data: (qibla) => compassAsync.when(
                    data: (event) {
                      final heading = event?.heading;
                      if (heading == null) return _waitingState();

                      final diff = _shortestAngleDiff(
                        qibla.qiblaDirection,
                        heading,
                      );
                      final isMatched = diff.abs() <= _matchToleranceDegrees;

                      if (isMatched && !_wasMatched)
                        HapticFeedback.mediumImpact();
                      _wasMatched = isMatched;

                      return _compassContent(
                        qibla.qiblaDirection,
                        qibla.distanceKm,
                        heading,
                        diff,
                        isMatched,
                      );
                    },
                    loading: _waitingState,
                    error: (_, __) => _waitingState(),
                  ),
                  loading: () => const Center(
                    child: CircularProgressIndicator(color: AppColors.gold),
                  ),
                  error: (error, _) => _errorState(error.toString()),
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
    double heading,
    double diff,
    bool isMatched,
  ) {
    return Column(
      children: [
        SizedBox(height: 12.h),
        SizedBox(
          height: 300.h,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Rotating ring — real compass card behavior.
              Transform.rotate(
                angle: -heading * math.pi / 180,
                child: CustomPaint(
                  size: Size(260.w, 260.w),
                  painter: QiblaRingPainter(
                    ringColor: AppColors.gold.withOpacity(0.5),
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
        SizedBox(height: 20.h),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
          decoration: BoxDecoration(
            color: isMatched
                ? AppColors.emeraldInk.withOpacity(0.12)
                : Colors.white.withOpacity(0.6),
            borderRadius: BorderRadius.circular(30.r),
          ),
          child: Text(
            isMatched
                ? 'You\'re facing the Qibla'
                : 'Rotate the phone ${diff.abs().round()}° to the ${diff > 0 ? 'right' : 'left'}',
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w500,
              color: isMatched ? AppColors.emeraldInk : AppColors.inkText,
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
            const CircularProgressIndicator(color: AppColors.gold),
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

  Widget _errorState(String message) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(20.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            SizedBox(height: 16.h),
            ElevatedButton(
              onPressed: () =>
                  ref.read(qiblaNotifierProvider.notifier).refresh(),
              child: const Text('Try again'),
            ),
          ],
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
