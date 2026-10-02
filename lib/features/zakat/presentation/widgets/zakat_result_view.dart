import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../shared/widgets/islamic_ornaments.dart';
import '../../domain/entities/zakat_calculation.dart';
import '../providers/zakat_providers.dart';
import 'zakat_common.dart';

/// Animated "amount due" hero, shared by the wealth and harvest results.
class ZakatAmountHero extends StatelessWidget {
  final bool due;
  final double amount;
  final String headline;
  final String caption;

  const ZakatAmountHero({
    super.key,
    required this.due,
    required this.amount,
    required this.headline,
    required this.caption,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28.r),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.heroSurface, AppColors.emeraldInkDark],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: GeometricPattern(
              color: AppColors.goldLight.withValues(alpha: 0.08),
              cell: 40,
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(22.w, 22.h, 22.w, 22.h),
            child: Column(
              children: [
                SizedBox(
                  width: 64.w,
                  height: 64.w,
                  child: CustomPaint(
                    painter: StarPainter(
                      fill: due
                          ? AppColors.gold
                          : AppColors.onHeroSurface.withValues(alpha: 0.12),
                      stroke: AppColors.goldLight,
                      strokeWidth: 1.4,
                    ),
                    child: Icon(
                      due ? Icons.check_rounded : Icons.info_outline_rounded,
                      size: 28.sp,
                      color: due ? AppColors.heroSurface : AppColors.goldLight,
                    ),
                  ),
                ).celebrate(),
                SizedBox(height: 12.h),
                Text(
                  headline.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11.sp,
                    letterSpacing: 1.6,
                    fontWeight: FontWeight.w700,
                    color: AppColors.gold,
                  ),
                ),
                SizedBox(height: 6.h),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: amount),
                  duration: context.motion.duration(AppMotion.value),
                  curve: AppMotion.entrance,
                  builder: (_, v, _) => FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      zakatFmt(v),
                      style: TextStyle(
                        fontSize: 44.sp,
                        fontWeight: FontWeight.w700,
                        color: AppColors.onHeroSurface,
                        height: 1.1,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 6.h),
                Text(
                  caption,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13.sp,
                    height: 1.45,
                    color: AppColors.onHeroSurface.withValues(alpha: 0.75),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Chips listing who zakat can be given to, from the guide content.
class ZakatRecipients extends ConsumerWidget {
  const ZakatRecipients({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = ref.watch(zakatInfoNotifierProvider).valueOrNull;
    if (info == null || info.eligibleRecipients.isEmpty) {
      return const SizedBox.shrink();
    }
    return ZakatCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.volunteer_activism_rounded,
                size: 18.sp,
                color: zakatAccent,
              ),
              SizedBox(width: 8.w),
              Text(
                'Who can receive your zakat',
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.inkText,
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Wrap(
            spacing: 8.w,
            runSpacing: 8.h,
            children: [
              for (final r in info.eligibleRecipients)
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 12.w,
                    vertical: 7.h,
                  ),
                  decoration: BoxDecoration(
                    color: zakatAccentBg,
                    borderRadius: BorderRadius.circular(14.r),
                  ),
                  child: Text(
                    r,
                    style: TextStyle(fontSize: 12.sp, color: AppColors.inkText),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class ZakatCalculationResultView extends StatelessWidget {
  final ZakatCalculationResult result;
  final VoidCallback onEdit;
  final VoidCallback onReset;

  const ZakatCalculationResultView({
    super.key,
    required this.result,
    required this.onEdit,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final b = result.breakdown;
    final parts = <(String, double, Color)>[
      ('Cash', b.cash, AppColors.quranAccent),
      ('Gold', b.goldValue, AppColors.gold),
      ('Silver', b.silverValue, AppColors.textMuted),
      ('Stocks', b.stocks, AppColors.duasAccent),
      ('Business goods', b.businessGoods, AppColors.hijriAccent),
      ('Other investments', b.otherInvestments, AppColors.worshipAccent),
    ].where((p) => p.$2 > 0).toList();

    return ListView(
      padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 32.h),
      children: [
        ZakatAmountHero(
          due: result.aboveNisab,
          amount: result.aboveNisab ? result.zakatDue : 0,
          headline: result.aboveNisab ? 'Zakat due' : 'Not due this year',
          caption: result.aboveNisab
              ? 'Calculated at ${result.rate} of your net zakatable wealth'
              : 'Your net wealth is below the nisab, so zakat is not obligatory. Any charity you give is still rewarded.',
        ).appear(),
        SizedBox(height: 14.h),
        _nisabGauge().slideIn(
          RevealDirection.start,
          delay: const Duration(milliseconds: 100),
          distance: 22,
        ),
        SizedBox(height: 14.h),
        ZakatCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Where your wealth comes from',
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.inkText,
                ),
              ),
              SizedBox(height: 12.h),
              if (parts.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(6.r),
                  child: SizedBox(
                    height: 12.h,
                    child: Row(
                      children: [
                        for (final p in parts)
                          Expanded(
                            flex: (p.$2 * 1000).round().clamp(1, 1 << 30),
                            child: Container(color: p.$3),
                          ),
                      ],
                    ),
                  ),
                ),
              SizedBox(height: 12.h),
              for (final p in parts) _legendRow(p.$1, p.$2, p.$3),
              Divider(height: 22.h, color: AppColors.borderWarm),
              _row('Gross wealth', b.grossWealth),
              _row('Debts deducted', -b.liabilities),
              _row('Net zakatable wealth', b.netZakatableWealth, bold: true),
            ],
          ),
        ).slideIn(
          RevealDirection.bottomEnd,
          delay: const Duration(milliseconds: 180),
          onVisible: true,
        ),
        SizedBox(height: 14.h),
        const ZakatRecipients().slideIn(
          RevealDirection.bottomStart,
          delay: const Duration(milliseconds: 240),
          onVisible: true,
        ),
        SizedBox(height: 14.h),
        Text(
          result.note,
          style: TextStyle(
            fontSize: 12.sp,
            height: 1.5,
            color: AppColors.textMuted,
          ),
        ).slideIn(RevealDirection.end, onVisible: true),
        SizedBox(height: 20.h),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_rounded, size: 18),
                label: const Text('Edit answers'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: zakatAccent,
                  side: BorderSide(color: zakatAccent.withValues(alpha: 0.5)),
                  padding: EdgeInsets.symmetric(vertical: 14.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                ),
              ).slideIn(RevealDirection.start, distance: 20, onVisible: true),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child:
                  FilledButton.icon(
                    onPressed: onReset,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Start over'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.heroSurface,
                      foregroundColor: AppColors.goldLight,
                      padding: EdgeInsets.symmetric(vertical: 14.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16.r),
                      ),
                    ),
                  ).slideIn(
                    RevealDirection.end,
                    distance: 20,
                    delay: const Duration(milliseconds: 60),
                    onVisible: true,
                  ),
            ),
          ],
        ),
      ],
    );
  }

  /// Net wealth against the nisab threshold, on a shared scale.
  Widget _nisabGauge() {
    final net = result.breakdown.netZakatableWealth;
    final nisab = result.nisabValue;
    final scale = (net > nisab ? net : nisab) * 1.2;
    final netF = scale <= 0 ? 0.0 : (net / scale).clamp(0.0, 1.0);
    final nisabF = scale <= 0 ? 0.0 : (nisab / scale).clamp(0.0, 1.0);

    return ZakatCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Your wealth vs nisab',
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.inkText,
                ),
              ),
              const Spacer(),
              Text(
                '${result.nisabStandard.name} standard',
                style: TextStyle(fontSize: 11.sp, color: AppColors.textMuted),
              ),
            ],
          ),
          SizedBox(height: 22.h),
          LayoutBuilder(
            builder: (context, c) {
              final w = c.maxWidth;
              return SizedBox(
                height: 30.h,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      top: 10.h,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: 10.h,
                        decoration: BoxDecoration(
                          color: AppColors.borderWarm,
                          borderRadius: BorderRadius.circular(5.r),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 10.h,
                      left: 0,
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: netF * w),
                        duration: context.motion.duration(AppMotion.value),
                        curve: AppMotion.entrance,
                        builder: (_, v, _) => Container(
                          width: v,
                          height: 10.h,
                          decoration: BoxDecoration(
                            color: result.aboveNisab
                                ? AppColors.gold
                                : zakatAccent,
                            borderRadius: BorderRadius.circular(5.r),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: nisabF * w - 1,
                      top: 0,
                      child: Container(
                        width: 2,
                        height: 30.h,
                        color: AppColors.inkText,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          SizedBox(height: 10.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _gaugeLabel('Your net wealth', zakatFmt(net)),
              _gaugeLabel('Nisab', zakatFmt(nisab), end: true),
            ],
          ),
          SizedBox(height: 10.h),
          Text(
            'Nisab = ${result.nisabGoldGrams} g gold or ${result.nisabSilverGrams} g silver',
            style: TextStyle(fontSize: 11.sp, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _gaugeLabel(String label, String value, {bool end = false}) {
    return Column(
      crossAxisAlignment: end
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 11.sp, color: AppColors.textSecondary),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 15.sp,
            fontWeight: FontWeight.w700,
            color: AppColors.inkText,
          ),
        ),
      ],
    );
  }

  Widget _legendRow(String label, double v, Color c) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: Row(
        children: [
          Container(
            width: 10.w,
            height: 10.w,
            decoration: BoxDecoration(color: c, shape: BoxShape.circle),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 13.sp, color: AppColors.textSecondary),
            ),
          ),
          Text(
            zakatFmt(v),
            style: TextStyle(
              fontSize: 13.sp,
              fontWeight: FontWeight.w600,
              color: AppColors.inkText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, double v, {bool bold = false}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13.sp,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
              color: bold ? AppColors.inkText : AppColors.textSecondary,
            ),
          ),
          Text(
            zakatFmt(v),
            style: TextStyle(
              fontSize: bold ? 15.sp : 13.sp,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
              color: AppColors.inkText,
            ),
          ),
        ],
      ),
    );
  }
}
