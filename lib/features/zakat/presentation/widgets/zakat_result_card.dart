import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/entities/zakat_calculation.dart';

class ZakatResultCard extends StatelessWidget {
  final ZakatCalculationResult result;
  const ZakatResultCard({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.all(20.w),
          decoration: BoxDecoration(
            color: result.aboveNisab
                ? AppColors.emeraldInk
                : AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(18.r),
            border: result.aboveNisab
                ? null
                : Border.all(color: AppColors.borderWarm),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    result.aboveNisab ? Icons.check_circle : Icons.info_outline,
                    color: result.aboveNisab
                        ? AppColors.gold
                        : AppColors.textMuted,
                    size: 20.sp,
                  ),
                  SizedBox(width: 8.w),
                  Text(
                    result.aboveNisab
                        ? 'Zakat is due'
                        : 'Below nisab — zakat not due',
                    style: AppTypography.titleMedium.copyWith(
                      color: result.aboveNisab
                          ? Colors.white
                          : AppColors.inkText,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16.h),
              if (result.aboveNisab) ...[
                Text(
                  result.zakatDue.toStringAsFixed(2),
                  style: AppTypography.heroSerif.copyWith(
                    color: Colors.white,
                    fontSize: 36.sp,
                  ),
                ),
                Text(
                  'at ${result.rate}',
                  style: AppTypography.bodyMedium.copyWith(
                    color: const Color(0xFFC9D6CF),
                  ),
                ),
                SizedBox(height: 12.h),
              ],
              Text(
                'Nisab threshold (${result.nisabStandard.name}): ${result.nisabValue.toStringAsFixed(2)}',
                style: AppTypography.bodyMedium.copyWith(
                  color: result.aboveNisab
                      ? Colors.white70
                      : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 12.h),
        Container(
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(14.r),
            border: Border.all(color: AppColors.borderWarm),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Breakdown',
                style: AppTypography.titleMedium.copyWith(
                  color: AppColors.inkText,
                ),
              ),
              SizedBox(height: 10.h),
              _row('Cash', result.breakdown.cash),
              _row('Gold value', result.breakdown.goldValue),
              _row('Silver value', result.breakdown.silverValue),
              _row('Stocks', result.breakdown.stocks),
              _row('Business goods', result.breakdown.businessGoods),
              _row('Other investments', result.breakdown.otherInvestments),
              Divider(height: 20.h, color: AppColors.borderWarm),
              _row('Gross wealth', result.breakdown.grossWealth, bold: true),
              _row('Liabilities deducted', -result.breakdown.liabilities),
              _row(
                'Net zakatable wealth',
                result.breakdown.netZakatableWealth,
                bold: true,
              ),
            ],
          ),
        ),
        SizedBox(height: 12.h),
        Text(
          result.note,
          style: AppTypography.bodyMedium.copyWith(color: AppColors.textMuted),
        ),
      ],
    );
  }

  Widget _row(String label, double value, {bool bold = false}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 3.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
              fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
          Text(
            value.toStringAsFixed(2),
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.inkText,
              fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}
