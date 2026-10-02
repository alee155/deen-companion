import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../domain/entities/zakat_calculation.dart';
import '../providers/zakat_providers.dart';
import '../widgets/zakat_common.dart';
import '../widgets/zakat_result_view.dart';

/// Harvest zakat: one interactive page. The illustrated field changes with
/// the water source, the estimate updates as you type, and the confirmed
/// result slides in below.
class ZakatAgricultureView extends ConsumerStatefulWidget {
  const ZakatAgricultureView({super.key});

  @override
  ConsumerState<ZakatAgricultureView> createState() =>
      _ZakatAgricultureViewState();
}

class _ZakatAgricultureViewState extends ConsumerState<ZakatAgricultureView>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final _value = TextEditingController();
  final _scroll = ScrollController();
  final _resultKey = GlobalKey();
  WaterSource _source = WaterSource.rain;

  double get _rate => _source == WaterSource.rain ? 0.10 : 0.05;
  double get _amount => zakatNum(_value);

  @override
  void initState() {
    super.initState();
    _value.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _value.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _calculate() async {
    if (_amount <= 0) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: const Text('Enter the value of your harvest first.'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      return;
    }
    FocusScope.of(context).unfocus();
    HapticFeedback.mediumImpact();
    await ref
        .read(agricultureZakatNotifierProvider.notifier)
        .calculate(_amount, _source);
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _resultKey.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: context.motion.duration(AppMotion.slow),
          curve: AppMotion.emphasized,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final state = ref.watch(agricultureZakatNotifierProvider);
    final result = state.valueOrNull;
    final loading = state.isLoading;

    return Column(
      children: [
        Expanded(
          child: ListView(
            controller: _scroll,
            padding: EdgeInsets.fromLTRB(20.w, 18.h, 20.w, 24.h),
            children: [
              _scene().slideIn(RevealDirection.top, distance: 18),
              SizedBox(height: 14.h),
              Row(
                children: [
                  _sourceCard(
                    WaterSource.rain,
                    'Rain-fed',
                    '10%',
                    'Rain, rivers, springs',
                    Icons.water_drop_rounded,
                    RevealDirection.start,
                  ),
                  SizedBox(width: 12.w),
                  _sourceCard(
                    WaterSource.irrigation,
                    'Irrigated',
                    '5%',
                    'Wells, pumps, carried water',
                    Icons.shower_rounded,
                    RevealDirection.end,
                  ),
                ],
              ),
              SizedBox(height: 14.h),
              ZakatCard(
                child: ZakatMoneyField(
                  controller: _value,
                  label: 'Value of your harvest',
                  hint: '0',
                  icon: Icons.agriculture_rounded,
                  large: true,
                ),
              ).slideIn(
                RevealDirection.bottomStart,
                delay: const Duration(milliseconds: 140),
              ),
              SizedBox(height: 14.h),
              _preview().slideIn(
                RevealDirection.bottomEnd,
                delay: const Duration(milliseconds: 200),
                onVisible: true,
              ),
              SizedBox(height: 14.h),
              ZakatFactStrip(
                factsFor: (i) => [
                  ZakatFact(
                    Icons.water_drop_rounded,
                    'Rain-fed',
                    '10%',
                    i.rateAgricultureRain,
                  ),
                  ZakatFact(
                    Icons.shower_rounded,
                    'Irrigated',
                    '5%',
                    i.rateAgricultureIrrigated,
                  ),
                ],
              ),
              if (state.hasError) ...[
                SizedBox(height: 12.h),
                Text(
                  state.error.toString(),
                  style: TextStyle(fontSize: 13.sp, color: AppColors.error),
                ),
              ],
              if (result != null && !loading) ...[
                SizedBox(key: _resultKey, height: 22.h),
                ZakatAmountHero(
                  due: true,
                  amount: result.zakatDue,
                  headline: 'Zakat on your harvest',
                  caption: 'At ${result.rate} of ${zakatFmt(result.value)}',
                ).appear(),
                SizedBox(height: 14.h),
                _split(result).slideIn(
                  RevealDirection.bottomStart,
                  delay: const Duration(milliseconds: 100),
                ),
                SizedBox(height: 14.h),
                Text(
                  result.note,
                  style: TextStyle(
                    fontSize: 12.sp,
                    height: 1.5,
                    color: AppColors.textMuted,
                  ),
                ).slideIn(
                  RevealDirection.end,
                  delay: const Duration(milliseconds: 160),
                ),
                SizedBox(height: 14.h),
                const ZakatRecipients().slideIn(
                  RevealDirection.bottom,
                  delay: const Duration(milliseconds: 220),
                  onVisible: true,
                ),
              ],
            ],
          ),
        ),
        Container(
          padding: EdgeInsets.fromLTRB(20.w, 10.h, 20.w, 10.h),
          decoration: BoxDecoration(
            color: AppColors.surfaceLight,
            border: Border(top: BorderSide(color: AppColors.borderWarm)),
          ),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: loading ? null : _calculate,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.gold,
                foregroundColor: AppColors.heroSurface,
                minimumSize: Size.fromHeight(48.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16.r),
                ),
              ),
              child: loading
                  ? SizedBox(
                      width: 20.w,
                      height: 20.w,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: AppColors.heroSurface,
                      ),
                    )
                  : Text(
                      result == null ? 'Calculate zakat' : 'Recalculate',
                      style: TextStyle(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _scene() {
    final rain = _source == WaterSource.rain;
    return ClipRRect(
      borderRadius: BorderRadius.circular(28.r),
      child: SizedBox(
        height: 170.h,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            AnimatedSwitcher(
              duration: context.motion.duration(AppMotion.slow),
              child: CustomPaint(
                key: ValueKey(rain),
                painter: _FieldPainter(rain: rain),
              ),
            ),
            Positioned(
              left: 16.w,
              top: 14.h,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color: AppColors.heroSurface.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(14.r),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedText(
                      rain ? '10%' : '5%',
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w700,
                        color: AppColors.goldLight,
                      ),
                    ),
                    SizedBox(width: 6.w),
                    Text(
                      rain ? 'of harvest' : 'of harvest',
                      style: TextStyle(
                        fontSize: 11.sp,
                        color: AppColors.onHeroSurface.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sourceCard(
    WaterSource s,
    String title,
    String rate,
    String sub,
    IconData icon,
    RevealDirection direction,
  ) {
    final sel = _source == s;
    return Expanded(
      child:
          Pressable(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _source = s);
            },
            child: AnimatedContainer(
              duration: context.motion.duration(AppMotion.normal),
              curve: AppMotion.entrance,
              padding: EdgeInsets.all(14.w),
              decoration: BoxDecoration(
                color: sel ? zakatAccentBg : AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(20.r),
                border: Border.all(
                  color: sel ? zakatAccent : AppColors.borderWarm,
                  width: sel ? 1.6 : 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        icon,
                        size: 20.sp,
                        color: sel ? zakatAccent : AppColors.textMuted,
                      ),
                      const Spacer(),
                      AnimatedOpacity(
                        duration: context.motion.duration(AppMotion.fast),
                        opacity: sel ? 1 : 0,
                        child: Icon(
                          Icons.check_circle_rounded,
                          size: 18.sp,
                          color: zakatAccent,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 10.h),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w700,
                      color: AppColors.inkText,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    sub,
                    style: TextStyle(
                      fontSize: 11.sp,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ).slideIn(
            direction,
            delay: const Duration(milliseconds: 80),
            distance: 22,
          ),
    );
  }

  /// Live "if you tapped calculate now" estimate.
  Widget _preview() {
    final due = _amount * _rate;
    return ZakatCard(
      color: zakatAccentBg,
      borderColor: zakatAccent.withValues(alpha: 0.2),
      child: Row(
        children: [
          Icon(Icons.auto_graph_rounded, color: zakatAccent, size: 22.sp),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Estimate',
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: AppColors.textSecondary,
                  ),
                ),
                TweenAnimationBuilder<double>(
                  tween: Tween(end: due),
                  duration: context.motion.duration(AppMotion.normal),
                  curve: AppMotion.entrance,
                  builder: (_, v, _) => Text(
                    '≈ ${zakatFmt(v)}',
                    style: TextStyle(
                      fontSize: 20.sp,
                      fontWeight: FontWeight.w700,
                      color: AppColors.inkText,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${(_rate * 100).round()}%',
            style: TextStyle(
              fontSize: 13.sp,
              fontWeight: FontWeight.w700,
              color: zakatAccent,
            ),
          ),
        ],
      ),
    );
  }

  Widget _split(AgricultureZakatResult r) {
    final total = r.value <= 0 ? 1.0 : r.value;
    final f = (r.zakatDue / total).clamp(0.0, 1.0);
    return ZakatCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your harvest, divided',
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.inkText,
            ),
          ),
          SizedBox(height: 12.h),
          AnimatedProgressBar(
            value: f,
            height: 16.h,
            color: AppColors.gold,
            backgroundColor: zakatAccent.withValues(alpha: 0.25),
          ),
          SizedBox(height: 12.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _key(AppColors.gold, 'Zakat', zakatFmt(r.zakatDue)),
              _key(
                zakatAccent.withValues(alpha: 0.5),
                'You keep',
                zakatFmt(r.value - r.zakatDue),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _key(Color c, String label, String value) {
    return Row(
      children: [
        Container(
          width: 10.w,
          height: 10.w,
          decoration: BoxDecoration(color: c, shape: BoxShape.circle),
        ),
        SizedBox(width: 8.w),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 11.sp, color: AppColors.textSecondary),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w700,
                color: AppColors.inkText,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Small illustrated field: rainy sky vs sunny sky with a sprinkler.
class _FieldPainter extends CustomPainter {
  final bool rain;
  const _FieldPainter({required this.rain});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;

    // Sky
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: rain
              ? const [Color(0xFF52707F), Color(0xFF9DB8C2)]
              : const [Color(0xFFF2C56B), Color(0xFFFBEBC8)],
        ).createShader(Offset.zero & size),
    );

    if (rain) {
      final cloud = Paint()..color = Colors.white.withValues(alpha: 0.85);
      for (final c in [
        (0.25, 0.22, 1.0),
        (0.62, 0.16, 1.25),
        (0.86, 0.3, 0.8),
      ]) {
        final o = Offset(w * c.$1, h * c.$2);
        final s = h * 0.13 * c.$3;
        canvas.drawCircle(o, s, cloud);
        canvas.drawCircle(o + Offset(s * 0.9, s * 0.2), s * 0.8, cloud);
        canvas.drawCircle(o - Offset(s * 0.9, -s * 0.2), s * 0.75, cloud);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(o.dx - s * 1.5, o.dy + s * 0.2, s * 3.3, s * 0.9),
            Radius.circular(s * 0.45),
          ),
          cloud,
        );
      }
      final drop = Paint()
        ..color = Colors.white.withValues(alpha: 0.7)
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round;
      for (var i = 0; i < 26; i++) {
        final x = (i * 0.041 + 0.03) * w;
        final y = h * (0.38 + (i * 37 % 20) / 100);
        canvas.drawLine(Offset(x, y), Offset(x - 4, y + 12), drop);
      }
    } else {
      final c = Offset(w * 0.82, h * 0.26);
      canvas.drawCircle(
        c,
        h * 0.3,
        Paint()
          ..shader = RadialGradient(
            colors: [Colors.white.withValues(alpha: 0.75), Colors.transparent],
          ).createShader(Rect.fromCircle(center: c, radius: h * 0.3)),
      );
      canvas.drawCircle(c, h * 0.11, Paint()..color = const Color(0xFFFFE08A));
    }

    // Hills
    final back = Path()
      ..moveTo(0, h * 0.7)
      ..quadraticBezierTo(w * 0.3, h * 0.5, w * 0.6, h * 0.66)
      ..quadraticBezierTo(w * 0.85, h * 0.78, w, h * 0.6)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(back, Paint()..color = const Color(0xFF6E9A5B));
    final front = Path()
      ..moveTo(0, h * 0.8)
      ..quadraticBezierTo(w * 0.4, h * 0.66, w, h * 0.84)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(front, Paint()..color = const Color(0xFF4F7D45));

    // Crop rows
    final stalk = Paint()
      ..color = const Color(0xFFE9CF74)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 16; i++) {
      final x = w * (0.04 + i * 0.062);
      final base = h * (0.93 - 0.02 * math.sin(i * 0.9));
      canvas.drawLine(Offset(x, base), Offset(x, base - 16), stalk);
      canvas.drawLine(Offset(x, base - 12), Offset(x - 5, base - 18), stalk);
      canvas.drawLine(Offset(x, base - 12), Offset(x + 5, base - 18), stalk);
    }

    if (!rain) {
      // Sprinkler with two water arcs.
      final base = Offset(w * 0.4, h * 0.82);
      canvas.drawLine(
        base,
        base - Offset(0, h * 0.12),
        Paint()
          ..color = const Color(0xFF3F4A4A)
          ..strokeWidth = 3,
      );
      final water = Paint()
        ..color = Colors.white.withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round;
      final top = base - Offset(0, h * 0.12);
      for (final dir in [-1.0, 1.0]) {
        for (final k in [0.8, 1.0, 1.2]) {
          final p = Path()
            ..moveTo(top.dx, top.dy)
            ..quadraticBezierTo(
              top.dx + dir * w * 0.09 * k,
              top.dy - h * 0.16 * k,
              top.dx + dir * w * 0.2 * k,
              top.dy + h * 0.06,
            );
          canvas.drawPath(p, water);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_FieldPainter old) => old.rain != rain;
}
