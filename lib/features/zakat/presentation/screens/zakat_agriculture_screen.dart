import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/entities/zakat_calculation.dart';
import '../providers/zakat_providers.dart';

class ZakatAgricultureScreen extends ConsumerStatefulWidget {
  const ZakatAgricultureScreen({super.key});

  @override
  ConsumerState<ZakatAgricultureScreen> createState() =>
      _ZakatAgricultureScreenState();
}

class _ZakatAgricultureScreenState
    extends ConsumerState<ZakatAgricultureScreen> {
  final _valueCtrl = TextEditingController();
  WaterSource _waterSource = WaterSource.rain;

  @override
  Widget build(BuildContext context) {
    final resultState = ref.watch(agricultureZakatNotifierProvider);

    return Scaffold(
      backgroundColor: AppColors.parchment,
      appBar: AppBar(
        title: const Text('Agricultural Zakat'),
        backgroundColor: AppColors.surfaceLight,
        foregroundColor: AppColors.inkText,
      ),
      body: Padding(
        padding: EdgeInsets.all(20.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Water source',
              style: AppTypography.titleMedium.copyWith(
                color: AppColors.inkText,
              ),
            ),
            SizedBox(height: 8.h),
            RadioListTile<WaterSource>(
              value: WaterSource.rain,
              groupValue: _waterSource,
              activeColor: AppColors.emeraldInk,
              title: const Text('Rain-fed (10%)'),
              onChanged: (v) => setState(() => _waterSource = v!),
            ),
            RadioListTile<WaterSource>(
              value: WaterSource.irrigation,
              groupValue: _waterSource,
              activeColor: AppColors.emeraldInk,
              title: const Text('Artificially irrigated (5%)'),
              onChanged: (v) => setState(() => _waterSource = v!),
            ),
            SizedBox(height: 12.h),
            TextField(
              controller: _valueCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'Value of harvested produce',
                filled: true,
                fillColor: AppColors.surfaceLight,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10.r),
                ),
              ),
            ),
            SizedBox(height: 20.h),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  final value = double.tryParse(_valueCtrl.text) ?? 0;
                  ref
                      .read(agricultureZakatNotifierProvider.notifier)
                      .calculate(value, _waterSource);
                },
                child: const Text('Calculate'),
              ),
            ),
            SizedBox(height: 20.h),
            resultState.when(
              data: (result) {
                if (result == null) return const SizedBox.shrink();
                return Container(
                  padding: EdgeInsets.all(20.w),
                  decoration: BoxDecoration(
                    color: AppColors.emeraldInk,
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Zakat due',
                        style: AppTypography.caption.copyWith(
                          color: Colors.white70,
                        ),
                      ),
                      SizedBox(height: 6.h),
                      Text(
                        result.zakatDue.toStringAsFixed(2),
                        style: AppTypography.heroSerif.copyWith(
                          color: Colors.white,
                          fontSize: 32.sp,
                        ),
                      ),
                      Text(
                        'at ${result.rate}',
                        style: AppTypography.bodyMedium.copyWith(
                          color: Colors.white70,
                        ),
                      ),
                      SizedBox(height: 10.h),
                      Text(
                        result.note,
                        style: AppTypography.bodyMedium.copyWith(
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                );
              },
              loading: () => const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
              error: (error, _) => Text(error.toString()),
            ),
          ],
        ),
      ),
    );
  }
}
