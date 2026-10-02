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

class _Asset {
  final String key;
  final String title;
  final String subtitle;
  final IconData icon;
  final TextEditingController ctrl;
  final String label;
  final String? suffix;
  final Color? tint;

  const _Asset({
    required this.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.ctrl,
    required this.label,
    this.suffix,
    this.tint,
  });
}

/// The wealth calculator as a short guided flow:
/// 1 Nisab → 2 Your wealth → 3 Review → result.
class ZakatCalculatorView extends ConsumerStatefulWidget {
  const ZakatCalculatorView({super.key});

  @override
  ConsumerState<ZakatCalculatorView> createState() =>
      _ZakatCalculatorViewState();
}

class _ZakatCalculatorViewState extends ConsumerState<ZakatCalculatorView>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  static const _stepTitles = ['Nisab', 'Wealth', 'Review'];

  int _step = 0;
  bool _forward = true;
  NisabStandard _standard = NisabStandard.gold;
  final Set<String> _selected = {};

  final _goldPrice = TextEditingController();
  final _silverPrice = TextEditingController();
  final _cash = TextEditingController();
  final _goldGrams = TextEditingController();
  final _silverGrams = TextEditingController();
  final _stocks = TextEditingController();
  final _business = TextEditingController();
  final _other = TextEditingController();
  final _liabilities = TextEditingController();

  late final List<_Asset> _assets;
  late final _Asset _debts;

  @override
  void initState() {
    super.initState();
    _assets = [
      _Asset(
        key: 'cash',
        title: 'Cash & savings',
        subtitle: 'Bank balances and cash in hand',
        icon: Icons.account_balance_wallet_rounded,
        ctrl: _cash,
        label: 'Total cash and savings',
      ),
      _Asset(
        key: 'gold',
        title: 'Gold',
        subtitle: 'Jewellery, coins and bars',
        icon: Icons.workspace_premium_rounded,
        ctrl: _goldGrams,
        label: 'Grams of gold owned',
        suffix: 'g',
      ),
      _Asset(
        key: 'silver',
        title: 'Silver',
        subtitle: 'Jewellery, coins and bars',
        icon: Icons.brightness_2_rounded,
        ctrl: _silverGrams,
        label: 'Grams of silver owned',
        suffix: 'g',
      ),
      _Asset(
        key: 'stocks',
        title: 'Stocks & shares',
        subtitle: 'Held for growth or trade',
        icon: Icons.trending_up_rounded,
        ctrl: _stocks,
        label: 'Monetary value of stocks/shares',
      ),
      _Asset(
        key: 'business',
        title: 'Business goods',
        subtitle: 'Inventory and trade goods',
        icon: Icons.storefront_rounded,
        ctrl: _business,
        label: 'Business inventory & trade goods value',
      ),
      _Asset(
        key: 'other',
        title: 'Other investments',
        subtitle: 'Property for sale, funds, lending',
        icon: Icons.pie_chart_rounded,
        ctrl: _other,
        label: 'Value of other investments',
      ),
    ];
    _debts = _Asset(
      key: 'debts',
      title: 'Debts & liabilities',
      subtitle: 'Short-term debts you owe now',
      icon: Icons.remove_circle_rounded,
      ctrl: _liabilities,
      label: 'Debts to deduct',
      tint: AppColors.error,
    );
    for (final c in [
      _goldPrice,
      _silverPrice,
      _cash,
      _goldGrams,
      _silverGrams,
      _stocks,
      _business,
      _other,
      _liabilities,
    ]) {
      c.addListener(_refresh);
    }
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    for (final c in [
      _goldPrice,
      _silverPrice,
      _cash,
      _goldGrams,
      _silverGrams,
      _stocks,
      _business,
      _other,
      _liabilities,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  bool _has(String k) => _selected.contains(k);
  bool get _needsGoldPrice => _standard == NisabStandard.gold || _has('gold');
  bool get _needsSilverPrice =>
      _standard == NisabStandard.silver || _has('silver');

  /// Local, instant estimate purely for the running total — the figure that
  /// counts always comes from the server.
  double get _estimatedNet {
    var t = 0.0;
    if (_has('cash')) t += zakatNum(_cash);
    if (_has('gold')) t += zakatNum(_goldGrams) * zakatNum(_goldPrice);
    if (_has('silver')) t += zakatNum(_silverGrams) * zakatNum(_silverPrice);
    if (_has('stocks')) t += zakatNum(_stocks);
    if (_has('business')) t += zakatNum(_business);
    if (_has('other')) t += zakatNum(_other);
    if (_has('debts')) t -= zakatNum(_liabilities);
    return t;
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  void _go(int step) {
    FocusScope.of(context).unfocus();
    setState(() {
      _forward = step > _step;
      _step = step;
    });
  }

  void _next() {
    if (_step == 0) {
      final price = _standard == NisabStandard.gold ? _goldPrice : _silverPrice;
      if (zakatNum(price) <= 0) {
        _toast(
          "Enter today's ${_standard.name} price per gram — it sets your nisab.",
        );
        return;
      }
    }
    if (_step == 1) {
      if (_selected.where((k) => k != 'debts').isEmpty) {
        _toast('Select at least one thing you own.');
        return;
      }
      if (_has('gold') && zakatNum(_goldPrice) <= 0) {
        _toast("Enter today's gold price per gram.");
        return;
      }
      if (_has('silver') && zakatNum(_silverPrice) <= 0) {
        _toast("Enter today's silver price per gram.");
        return;
      }
    }
    HapticFeedback.selectionClick();
    _go(_step + 1);
  }

  Future<void> _calculate() async {
    HapticFeedback.mediumImpact();
    final notifier = ref.read(zakatCalculatorNotifierProvider.notifier);
    await notifier.calculate(
      ZakatCalculationInput(
        goldPricePerGram: _needsGoldPrice ? zakatNum(_goldPrice) : null,
        silverPricePerGram: _needsSilverPrice ? zakatNum(_silverPrice) : null,
        nisabStandard: _standard,
        includeCash: _has('cash'),
        cash: zakatNum(_cash),
        includeGold: _has('gold'),
        goldGrams: zakatNum(_goldGrams),
        includeSilver: _has('silver'),
        silverGrams: zakatNum(_silverGrams),
        includeStocks: _has('stocks'),
        stocks: zakatNum(_stocks),
        includeBusinessGoods: _has('business'),
        businessGoods: zakatNum(_business),
        includeOtherInvestments: _has('other'),
        otherInvestments: zakatNum(_other),
        includeLiabilities: _has('debts'),
        liabilities: zakatNum(_liabilities),
      ),
    );
    if (!mounted) return;
    final state = ref.read(zakatCalculatorNotifierProvider);
    if (state.hasError) {
      _toast(state.error.toString());
    } else if (state.valueOrNull != null) {
      _go(3);
    }
  }

  void _reset() {
    ref.read(zakatCalculatorNotifierProvider.notifier).reset();
    for (final c in [
      _goldPrice,
      _silverPrice,
      _cash,
      _goldGrams,
      _silverGrams,
      _stocks,
      _business,
      _other,
      _liabilities,
    ]) {
      c.clear();
    }
    _selected.clear();
    _standard = NisabStandard.gold;
    _go(0);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final result = ref.watch(zakatCalculatorNotifierProvider).valueOrNull;
    final showResult = _step == 3 && result != null;

    return Column(
      children: [
        if (!showResult) _stepper(),
        Expanded(
          child: AnimatedSwitcher(
            duration: context.motion.duration(AppMotion.normal),
            switchInCurve: AppMotion.entrance,
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: SlideTransition(
                position: Tween(
                  begin: Offset(_forward ? 0.06 : -0.06, 0),
                  end: Offset.zero,
                ).animate(anim),
                child: child,
              ),
            ),
            child: KeyedSubtree(
              key: ValueKey(showResult ? 3 : _step),
              child: showResult
                  ? ZakatCalculationResultView(
                      result: result,
                      onEdit: () => _go(2),
                      onReset: _reset,
                    )
                  : _stepBody(),
            ),
          ),
        ),
        if (!showResult) _bottomBar(),
      ],
    );
  }

  // ── Stepper ───────────────────────────────────────────────────────────

  Widget _stepper() {
    return Padding(
      padding: EdgeInsets.fromLTRB(24.w, 18.h, 24.w, 4.h),
      child: Row(
        children: List.generate(_stepTitles.length * 2 - 1, (i) {
          if (i.isOdd) {
            final filled = _step > i ~/ 2;
            return Expanded(
              child: AnimatedContainer(
                duration: context.motion.duration(AppMotion.normal),
                height: 2,
                margin: EdgeInsets.only(bottom: 18.h),
                color: filled ? zakatAccent : AppColors.borderWarm,
              ),
            );
          }
          final idx = i ~/ 2;
          final done = _step > idx;
          final active = _step == idx;
          return Pressable(
            scale: AppMotion.pressScaleSmall,
            onTap: idx < _step ? () => _go(idx) : null,
            child: Column(
              children: [
                AnimatedContainer(
                  duration: context.motion.duration(AppMotion.normal),
                  width: 30.w,
                  height: 30.w,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: done || active
                        ? zakatAccent
                        : AppColors.surfaceLight,
                    border: Border.all(
                      color: done || active
                          ? zakatAccent
                          : AppColors.borderWarm,
                      width: 1.5,
                    ),
                  ),
                  child: IconSwap(
                    child: done
                        ? Icon(
                            Icons.check_rounded,
                            key: const ValueKey('done'),
                            size: 16.sp,
                            color: AppColors.surfaceLight,
                          )
                        : Text(
                            '${idx + 1}',
                            key: const ValueKey('num'),
                            style: TextStyle(
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w700,
                              color: active
                                  ? AppColors.surfaceLight
                                  : AppColors.textMuted,
                            ),
                          ),
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  _stepTitles[idx],
                  style: TextStyle(
                    fontSize: 11.sp,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    color: active ? AppColors.inkText : AppColors.textMuted,
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _stepBody() {
    switch (_step) {
      case 0:
        return _nisabStep();
      case 1:
        return _wealthStep();
      default:
        return _reviewStep();
    }
  }

  Widget _heading(String title, String sub) {
    final seq = RevealSequence();
    return Padding(
      padding: EdgeInsets.only(bottom: 16.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 22.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.inkText,
            ),
          ).slideIn(RevealDirection.topStart, delay: seq.next()),
          SizedBox(height: 4.h),
          Text(
            sub,
            style: TextStyle(
              fontSize: 13.sp,
              height: 1.45,
              color: AppColors.textSecondary,
            ),
          ).slideIn(RevealDirection.bottomStart, delay: seq.next()),
        ],
      ),
    );
  }

  // ── Step 1: Nisab ─────────────────────────────────────────────────────

  Widget _nisabStep() {
    final info = ref.watch(zakatInfoNotifierProvider).valueOrNull;
    final gold = _standard == NisabStandard.gold;

    Widget option(
      NisabStandard s,
      String title,
      IconData icon,
      String grams,
      RevealDirection dir,
    ) {
      final sel = _standard == s;
      return Expanded(
        child: Pressable(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _standard = s);
          },
          child: AnimatedContainer(
            duration: context.motion.duration(AppMotion.normal),
            curve: AppMotion.entrance,
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: sel ? AppColors.heroSurface : AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(22.r),
              border: Border.all(
                color: sel ? AppColors.gold : AppColors.borderWarm,
                width: sel ? 1.6 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  icon,
                  size: 28.sp,
                  color: sel ? AppColors.goldLight : zakatAccent,
                ),
                SizedBox(height: 14.h),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w700,
                    color: sel ? AppColors.onHeroSurface : AppColors.inkText,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  grams.isEmpty ? 'Threshold' : '$grams g threshold',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: sel
                        ? AppColors.onHeroSurface.withValues(alpha: 0.7)
                        : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ).slideIn(dir, delay: const Duration(milliseconds: 80), distance: 22),
      );
    }

    return ListView(
      padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 24.h),
      children: [
        _heading(
          'Set your nisab',
          'Zakat is only due once your wealth passes a minimum threshold. Choose which metal to measure it by.',
        ),
        Row(
          children: [
            option(
              NisabStandard.gold,
              'Gold',
              Icons.workspace_premium_rounded,
              info == null ? '' : '${info.nisabGold.grams}',
              RevealDirection.start,
            ),
            SizedBox(width: 12.w),
            option(
              NisabStandard.silver,
              'Silver',
              Icons.brightness_2_rounded,
              info == null ? '' : '${info.nisabSilver.grams}',
              RevealDirection.end,
            ),
          ],
        ),
        SizedBox(height: 16.h),
        ZakatCard(
          child: ZakatMoneyField(
            controller: gold ? _goldPrice : _silverPrice,
            label: "Today's ${gold ? 'gold' : 'silver'} price per gram",
            icon: Icons.sell_rounded,
          ),
        ).slideIn(
          RevealDirection.bottom,
          delay: const Duration(milliseconds: 140),
        ),
        SizedBox(height: 22.h),
        Text(
          'Good to know',
          style: TextStyle(
            fontSize: 15.sp,
            fontWeight: FontWeight.w700,
            color: AppColors.inkText,
          ),
        ).slideIn(RevealDirection.topStart, distance: 16, onVisible: true),
        SizedBox(height: 10.h),
        ZakatFactStrip(
          factsFor: (i) => [
            ZakatFact(
              Icons.balance_rounded,
              'Rate',
              i.rateGeneral,
              i.nisabNote,
            ),
            ZakatFact(
              Icons.hourglass_bottom_rounded,
              'Hawl',
              'One lunar year',
              i.hawl,
            ),
            ZakatFact(
              Icons.rule_rounded,
              'Conditions',
              '${i.conditions.length} to meet',
              i.conditions.join(' · '),
            ),
          ],
        ),
        SizedBox(height: 8.h),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => showZakatGuide(context),
            icon: const Icon(Icons.menu_book_rounded, size: 18),
            label: const Text('Read the full guide'),
            style: TextButton.styleFrom(foregroundColor: zakatAccent),
          ),
        ).slideIn(RevealDirection.bottomStart, onVisible: true),
      ],
    );
  }

  // ── Step 2: Wealth ────────────────────────────────────────────────────

  Widget _wealthStep() {
    return ListView(
      padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 24.h),
      children: [
        _heading(
          'What do you own?',
          'Tap everything that applies, then fill in its value. Skip what you don’t have.',
        ),
        for (var i = 0; i < _assets.length; i++)
          Padding(
            padding: EdgeInsets.only(bottom: 10.h),
            child: _assetCard(_assets[i]).slideInAt(i),
          ),
      ],
    );
  }

  Widget _assetCard(_Asset a) {
    final sel = _has(a.key);
    final tint = a.tint ?? zakatAccent;
    final metalNeedsPrice =
        (a.key == 'gold' && _standard != NisabStandard.gold) ||
        (a.key == 'silver' && _standard != NisabStandard.silver);

    return AnimatedContainer(
      duration: context.motion.duration(AppMotion.normal),
      curve: AppMotion.entrance,
      decoration: BoxDecoration(
        color: sel ? tint.withValues(alpha: 0.07) : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(22.r),
        border: Border.all(
          color: sel ? tint : AppColors.borderWarm,
          width: sel ? 1.5 : 1,
        ),
      ),
      child: Column(
        children: [
          PressScale(
            child: InkWell(
              borderRadius: BorderRadius.circular(22.r),
              onTap: () {
                HapticFeedback.selectionClick();
                setState(
                  () => sel ? _selected.remove(a.key) : _selected.add(a.key),
                );
              },
              child: Padding(
                padding: EdgeInsets.all(14.w),
                child: Row(
                  children: [
                    AnimatedContainer(
                      duration: context.motion.duration(AppMotion.fast),
                      width: 44.w,
                      height: 44.w,
                      decoration: BoxDecoration(
                        color: sel ? tint : tint.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14.r),
                      ),
                      child: Icon(
                        a.icon,
                        size: 22.sp,
                        color: sel ? AppColors.surfaceLight : tint,
                      ),
                    ),
                    SizedBox(width: 14.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            a.title,
                            style: TextStyle(
                              fontSize: 15.sp,
                              fontWeight: FontWeight.w700,
                              color: AppColors.inkText,
                            ),
                          ),
                          Text(
                            a.subtitle,
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconSwap(
                      child: Icon(
                        sel
                            ? Icons.check_circle_rounded
                            : Icons.add_circle_outline_rounded,
                        key: ValueKey(sel),
                        color: sel ? tint : AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          ExpandSection(
            expanded: sel,
            child: Padding(
              padding: EdgeInsets.fromLTRB(14.w, 0, 14.w, 14.h),
              child: Column(
                children: [
                  ZakatMoneyField(
                    controller: a.ctrl,
                    label: a.label,
                    suffix: a.suffix,
                  ),
                  if (metalNeedsPrice) ...[
                    SizedBox(height: 10.h),
                    ZakatMoneyField(
                      controller: a.key == 'gold' ? _goldPrice : _silverPrice,
                      label: "Today's ${a.key} price per gram",
                      icon: Icons.sell_rounded,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Step 3: Review ────────────────────────────────────────────────────

  Widget _reviewStep() {
    final rows = <(String, IconData, double)>[];
    for (final a in _assets) {
      if (!_has(a.key)) continue;
      final v = switch (a.key) {
        'gold' => zakatNum(_goldGrams) * zakatNum(_goldPrice),
        'silver' => zakatNum(_silverGrams) * zakatNum(_silverPrice),
        _ => zakatNum(a.ctrl),
      };
      rows.add((a.title, a.icon, v));
    }
    final info = ref.watch(zakatInfoNotifierProvider).valueOrNull;
    final price = _standard == NisabStandard.gold
        ? zakatNum(_goldPrice)
        : zakatNum(_silverPrice);
    final grams = info == null
        ? null
        : (_standard == NisabStandard.gold
              ? info.nisabGold.grams
              : info.nisabSilver.grams);
    final nisab = grams == null ? null : grams * price;
    final net = _estimatedNet;

    return ListView(
      padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 24.h),
      children: [
        _heading(
          'Any debts to deduct?',
          'Debts due now reduce the wealth zakat is calculated on. Then check your summary.',
        ),
        _assetCard(_debts).slideIn(RevealDirection.start, distance: 22),
        SizedBox(height: 18.h),
        ZakatCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your summary',
                style: TextStyle(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.inkText,
                ),
              ),
              SizedBox(height: 10.h),
              for (final r in rows)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 5.h),
                  child: Row(
                    children: [
                      Icon(r.$2, size: 18.sp, color: zakatAccent),
                      SizedBox(width: 10.w),
                      Expanded(
                        child: Text(
                          r.$1,
                          style: TextStyle(
                            fontSize: 13.sp,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      Text(
                        zakatFmt(r.$3),
                        style: TextStyle(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w600,
                          color: AppColors.inkText,
                        ),
                      ),
                    ],
                  ),
                ),
              if (_has('debts'))
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 5.h),
                  child: Row(
                    children: [
                      Icon(
                        Icons.remove_circle_rounded,
                        size: 18.sp,
                        color: AppColors.error,
                      ),
                      SizedBox(width: 10.w),
                      Expanded(
                        child: Text(
                          'Debts',
                          style: TextStyle(
                            fontSize: 13.sp,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      Text(
                        '-${zakatFmt(zakatNum(_liabilities))}',
                        style: TextStyle(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w600,
                          color: AppColors.error,
                        ),
                      ),
                    ],
                  ),
                ),
              Divider(height: 22.h, color: AppColors.borderWarm),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Estimated net wealth',
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w700,
                        color: AppColors.inkText,
                      ),
                    ),
                  ),
                  Text(
                    zakatFmt(net),
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w700,
                      color: AppColors.inkText,
                    ),
                  ),
                ],
              ),
              if (nisab != null && nisab > 0) ...[
                SizedBox(height: 12.h),
                Container(
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(
                    color: net >= nisab
                        ? AppColors.gold.withValues(alpha: 0.14)
                        : zakatAccentBg,
                    borderRadius: BorderRadius.circular(14.r),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        net >= nisab
                            ? Icons.trending_up_rounded
                            : Icons.trending_flat_rounded,
                        size: 18.sp,
                        color: net >= nisab ? AppColors.gold : zakatAccent,
                      ),
                      SizedBox(width: 10.w),
                      Expanded(
                        child: AnimatedText(
                          net >= nisab
                              ? 'Looks above the nisab of ${zakatFmt(nisab)} — zakat is likely due.'
                              : 'Looks below the nisab of ${zakatFmt(nisab)}.',
                          style: TextStyle(
                            fontSize: 12.sp,
                            height: 1.4,
                            color: AppColors.inkText,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ).slideIn(
          RevealDirection.bottomEnd,
          delay: const Duration(milliseconds: 100),
          onVisible: true,
        ),
        SizedBox(height: 10.h),
        Text(
          'This is a quick estimate. Tap Calculate for the confirmed figure.',
          style: TextStyle(fontSize: 11.sp, color: AppColors.textMuted),
        ).slideIn(
          RevealDirection.bottomStart,
          delay: const Duration(milliseconds: 180),
          onVisible: true,
        ),
      ],
    );
  }

  // ── Bottom bar ────────────────────────────────────────────────────────

  Widget _bottomBar() {
    final loading = ref.watch(zakatCalculatorNotifierProvider).isLoading;
    final last = _step == 2;
    return Container(
      padding: EdgeInsets.fromLTRB(
        20.w,
        10.h,
        20.w,
        10.h + MediaQuery.of(context).viewInsets.bottom * 0,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        border: Border(top: BorderSide(color: AppColors.borderWarm)),
      ),
      child: Row(
        children: [
          if (_step > 0)
            Padding(
              padding: EdgeInsets.only(right: 10.w),
              child: IconButton.outlined(
                onPressed: () => _go(_step - 1),
                icon: const Icon(Icons.arrow_back_rounded),
                style: IconButton.styleFrom(
                  foregroundColor: AppColors.inkText,
                  side: BorderSide(color: AppColors.borderWarm),
                  fixedSize: Size(48.w, 48.w),
                ),
              ),
            ),
          if (_step > 0)
            Padding(
              padding: EdgeInsets.only(right: 14.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Net wealth',
                    style: TextStyle(
                      fontSize: 10.sp,
                      color: AppColors.textMuted,
                    ),
                  ),
                  TweenAnimationBuilder<double>(
                    tween: Tween(end: _estimatedNet),
                    duration: context.motion.duration(AppMotion.normal),
                    curve: AppMotion.entrance,
                    builder: (_, v, _) => Text(
                      zakatFmt(v),
                      style: TextStyle(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w700,
                        color: AppColors.inkText,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: FilledButton(
              onPressed: loading ? null : (last ? _calculate : _next),
              style: FilledButton.styleFrom(
                backgroundColor: last ? AppColors.gold : AppColors.heroSurface,
                foregroundColor: last
                    ? AppColors.heroSurface
                    : AppColors.goldLight,
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
                      last ? 'Calculate zakat' : 'Continue',
                      style: TextStyle(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
