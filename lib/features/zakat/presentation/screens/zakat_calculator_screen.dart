import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/entities/zakat_calculation.dart';
import '../providers/zakat_providers.dart';
import '../widgets/zakat_asset_input_section.dart';
import '../widgets/zakat_result_card.dart';

class ZakatCalculatorScreen extends ConsumerStatefulWidget {
  const ZakatCalculatorScreen({super.key});

  @override
  ConsumerState<ZakatCalculatorScreen> createState() =>
      _ZakatCalculatorScreenState();
}

class _ZakatCalculatorScreenState extends ConsumerState<ZakatCalculatorScreen> {
  NisabStandard _nisabStandard = NisabStandard.gold;
  bool _includeCash = false, _includeGold = false, _includeSilver = false;
  bool _includeStocks = false,
      _includeBusinessGoods = false,
      _includeOtherInvestments = false,
      _includeLiabilities = false;

  final _goldPriceCtrl = TextEditingController();
  final _silverPriceCtrl = TextEditingController();
  final _cashCtrl = TextEditingController();
  final _goldGramsCtrl = TextEditingController();
  final _silverGramsCtrl = TextEditingController();
  final _stocksCtrl = TextEditingController();
  final _businessGoodsCtrl = TextEditingController();
  final _otherInvestmentsCtrl = TextEditingController();
  final _liabilitiesCtrl = TextEditingController();

  double _num(TextEditingController c) => double.tryParse(c.text) ?? 0;
  bool get _needsGoldPrice =>
      _nisabStandard == NisabStandard.gold || _includeGold;
  bool get _needsSilverPrice =>
      _nisabStandard == NisabStandard.silver || _includeSilver;

  Widget _numberField(
    TextEditingController controller,
    String label, {
    bool required = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(top: 8.h),
      child: TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: required ? '$label *' : label,
          filled: true,
          fillColor: AppColors.parchment,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10.r),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  void _submit() {
    if (_needsGoldPrice && _num(_goldPriceCtrl) <= 0) {
      _showError(
        'Enter today\'s gold price per gram — required for the gold nisab standard.',
      );
      return;
    }
    if (_needsSilverPrice && _num(_silverPriceCtrl) <= 0) {
      _showError(
        'Enter today\'s silver price per gram — required for the silver nisab standard.',
      );
      return;
    }

    ref
        .read(zakatCalculatorNotifierProvider.notifier)
        .calculate(
          ZakatCalculationInput(
            goldPricePerGram: _needsGoldPrice ? _num(_goldPriceCtrl) : null,
            silverPricePerGram: _needsSilverPrice
                ? _num(_silverPriceCtrl)
                : null,
            nisabStandard: _nisabStandard,
            includeCash: _includeCash,
            cash: _num(_cashCtrl),
            includeGold: _includeGold,
            goldGrams: _num(_goldGramsCtrl),
            includeSilver: _includeSilver,
            silverGrams: _num(_silverGramsCtrl),
            includeStocks: _includeStocks,
            stocks: _num(_stocksCtrl),
            includeBusinessGoods: _includeBusinessGoods,
            businessGoods: _num(_businessGoodsCtrl),
            includeOtherInvestments: _includeOtherInvestments,
            otherInvestments: _num(_otherInvestmentsCtrl),
            includeLiabilities: _includeLiabilities,
            liabilities: _num(_liabilitiesCtrl),
          ),
        );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final resultState = ref.watch(zakatCalculatorNotifierProvider);

    return Scaffold(
      backgroundColor: AppColors.parchment,
      appBar: AppBar(
        title: const Text('Zakat Calculator'),
        backgroundColor: AppColors.surfaceLight,
        foregroundColor: AppColors.inkText,
      ),
      body: ListView(
        padding: EdgeInsets.all(20.w),
        children: [
          Text(
            'Nisab standard',
            style: AppTypography.titleMedium.copyWith(color: AppColors.inkText),
          ),
          SizedBox(height: 4.h),
          Text(
            'This determines the minimum wealth threshold before zakat is due.',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          SizedBox(height: 10.h),
          Container(
            padding: EdgeInsets.all(4.w),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: AppColors.borderWarm),
            ),
            child: Row(
              children: [
                Expanded(child: _standardTab('Gold', NisabStandard.gold)),
                Expanded(child: _standardTab('Silver', NisabStandard.silver)),
              ],
            ),
          ),
          SizedBox(height: 20.h),

          if (_needsGoldPrice || _needsSilverPrice) ...[
            Text(
              'Today\'s metal prices',
              style: AppTypography.titleMedium.copyWith(
                color: AppColors.inkText,
              ),
            ),
            Container(
              margin: EdgeInsets.only(top: 8.h, bottom: 12.h),
              padding: EdgeInsets.all(14.w),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(14.r),
                border: Border.all(color: AppColors.borderWarm),
              ),
              child: Column(
                children: [
                  if (_needsGoldPrice)
                    _numberField(
                      _goldPriceCtrl,
                      'Gold price per gram',
                      required: true,
                    ),
                  if (_needsSilverPrice)
                    _numberField(
                      _silverPriceCtrl,
                      'Silver price per gram',
                      required: true,
                    ),
                ],
              ),
            ),
          ],

          Text(
            'What would you like to include?',
            style: AppTypography.titleMedium.copyWith(color: AppColors.inkText),
          ),
          SizedBox(height: 10.h),

          ZakatAssetInputSection(
            title: 'Cash & Savings',
            icon: Icons.account_balance_wallet_outlined,
            checked: _includeCash,
            onCheckedChanged: (v) => setState(() => _includeCash = v),
            fields: [_numberField(_cashCtrl, 'Total cash and savings')],
          ),
          ZakatAssetInputSection(
            title: 'Gold',
            icon: Icons.circle,
            checked: _includeGold,
            onCheckedChanged: (v) => setState(() => _includeGold = v),
            fields: [_numberField(_goldGramsCtrl, 'Grams of gold owned')],
          ),
          ZakatAssetInputSection(
            title: 'Silver',
            icon: Icons.circle_outlined,
            checked: _includeSilver,
            onCheckedChanged: (v) => setState(() => _includeSilver = v),
            fields: [_numberField(_silverGramsCtrl, 'Grams of silver owned')],
          ),
          ZakatAssetInputSection(
            title: 'Stocks & Shares',
            icon: Icons.trending_up,
            checked: _includeStocks,
            onCheckedChanged: (v) => setState(() => _includeStocks = v),
            fields: [
              _numberField(_stocksCtrl, 'Monetary value of stocks/shares'),
            ],
          ),
          ZakatAssetInputSection(
            title: 'Business Goods',
            icon: Icons.store_outlined,
            checked: _includeBusinessGoods,
            onCheckedChanged: (v) => setState(() => _includeBusinessGoods = v),
            fields: [
              _numberField(
                _businessGoodsCtrl,
                'Business inventory & trade goods value',
              ),
            ],
          ),
          ZakatAssetInputSection(
            title: 'Other Investments',
            icon: Icons.pie_chart_outline,
            checked: _includeOtherInvestments,
            onCheckedChanged: (v) =>
                setState(() => _includeOtherInvestments = v),
            fields: [
              _numberField(_otherInvestmentsCtrl, 'Value of other investments'),
            ],
          ),
          ZakatAssetInputSection(
            title: 'Debts & Liabilities',
            icon: Icons.remove_circle_outline,
            checked: _includeLiabilities,
            onCheckedChanged: (v) => setState(() => _includeLiabilities = v),
            fields: [_numberField(_liabilitiesCtrl, 'Debts to deduct')],
          ),

          SizedBox(height: 12.h),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submit,
              child: const Text('Calculate Zakat'),
            ),
          ),
          SizedBox(height: 20.h),

          resultState.when(
            data: (result) => result == null
                ? const SizedBox.shrink()
                : ZakatResultCard(result: result),
            loading: () => const Center(
              child: CircularProgressIndicator(color: AppColors.emeraldInk),
            ),
            error: (error, _) => Text(
              error.toString(),
              style: AppTypography.bodyMedium.copyWith(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }

  Widget _standardTab(String label, NisabStandard value) {
    final selected = _nisabStandard == value;
    return GestureDetector(
      onTap: () => setState(() => _nisabStandard = value),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 10.h),
        decoration: BoxDecoration(
          color: selected ? AppColors.emeraldInk : Colors.transparent,
          borderRadius: BorderRadius.circular(9.r),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: AppTypography.bodyMedium.copyWith(
            color: selected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
