import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../providers/zakat_providers.dart';

class ZakatInfoScreen extends ConsumerWidget {
  const ZakatInfoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final infoAsync = ref.watch(zakatInfoNotifierProvider);

    return Scaffold(
      backgroundColor: AppColors.parchment,
      appBar: AppBar(
        title: const Text('About Zakat'),
        backgroundColor: AppColors.surfaceLight,
        foregroundColor: AppColors.inkText,
      ),
      body: infoAsync.when(
        data: (info) => ListView(
          padding: EdgeInsets.all(20.w),
          children: [
            Text(
              info.definition,
              style: AppTypography.bodyLarge.copyWith(color: AppColors.inkText),
            ),
            SizedBox(height: 20.h),
            _section('Conditions', info.conditions),
            _section('Zakatable assets', info.zakatableAssets),
            _section('Not zakatable', info.nonZakatableAssets),
            _section('Eligible recipients', info.eligibleRecipients),
            SizedBox(height: 8.h),
            Container(
              padding: EdgeInsets.all(14.w),
              decoration: BoxDecoration(
                color: AppColors.toolsAccentBg,
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Text(
                info.disclaimer,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.inkText,
                ),
              ),
            ),
          ],
        ),
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.emeraldInk),
        ),
        error: (error, _) => Center(child: Text(error.toString())),
      ),
    );
  }

  Widget _section(String title, List<String> items) {
    return Padding(
      padding: EdgeInsets.only(bottom: 20.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTypography.titleMedium.copyWith(color: AppColors.inkText),
          ),
          SizedBox(height: 8.h),
          ...items.map(
            (item) => Padding(
              padding: EdgeInsets.only(bottom: 6.h),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.circle, size: 5.sp, color: AppColors.toolsAccent),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      item,
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
