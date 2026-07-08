import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../providers/islamic_calendar_providers.dart';

class HijriPickedDate {
  final int year;
  final int month;
  final int day;
  const HijriPickedDate({
    required this.year,
    required this.month,
    required this.day,
  });
}

Future<HijriPickedDate?> showHijriDatePicker(
  BuildContext context, {
  required int initialYear,
}) {
  return showModalBottomSheet<HijriPickedDate>(
    context: context,
    backgroundColor: AppColors.surfaceLight,
    isScrollControlled: true,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
    ),
    builder: (context) => _HijriPickerSheetContent(initialYear: initialYear),
  );
}

class _HijriPickerSheetContent extends ConsumerStatefulWidget {
  final int initialYear;
  const _HijriPickerSheetContent({required this.initialYear});

  @override
  ConsumerState<_HijriPickerSheetContent> createState() =>
      _HijriPickerSheetContentState();
}

class _HijriPickerSheetContentState
    extends ConsumerState<_HijriPickerSheetContent> {
  late int _year;
  int _monthIndex = 0; // 0-based
  int _day = 1;

  @override
  void initState() {
    super.initState();
    _year = widget.initialYear;
  }

  @override
  Widget build(BuildContext context) {
    final monthsAsync = ref.watch(islamicMonthsNotifierProvider);
    final years = List.generate(161, (i) => 1300 + i); // 1300–1460 AH

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(top: 12.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: AppColors.borderWarm,
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
            SizedBox(height: 14.h),
            Text(
              'Select Hijri date',
              style: AppTypography.titleMedium.copyWith(
                color: AppColors.inkText,
              ),
            ),
            SizedBox(height: 12.h),
            monthsAsync.when(
              data: (months) => SizedBox(
                height: 160.h,
                child: Row(
                  children: [
                    Expanded(
                      child: CupertinoPicker(
                        itemExtent: 36.h,
                        scrollController: FixedExtentScrollController(
                          initialItem: years.indexOf(_year),
                        ),
                        onSelectedItemChanged: (i) =>
                            setState(() => _year = years[i]),
                        children: years
                            .map(
                              (y) => Center(
                                child: Text(
                                  '$y AH',
                                  style: AppTypography.bodyLarge,
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: CupertinoPicker(
                        itemExtent: 36.h,
                        onSelectedItemChanged: (i) =>
                            setState(() => _monthIndex = i),
                        children: months
                            .map(
                              (m) => Center(
                                child: Text(
                                  m.nameEnglish,
                                  style: AppTypography.bodyLarge,
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                    Expanded(
                      child: CupertinoPicker(
                        itemExtent: 36.h,
                        onSelectedItemChanged: (i) =>
                            setState(() => _day = i + 1),
                        children: List.generate(
                          30,
                          (i) => Center(
                            child: Text(
                              '${i + 1}',
                              style: AppTypography.bodyLarge,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              loading: () => SizedBox(
                height: 160.h,
                child: const Center(child: CircularProgressIndicator()),
              ),
              error: (_, __) => SizedBox(
                height: 160.h,
                child: const Center(child: Text('Could not load months')),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 20.h),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(
                    HijriPickedDate(
                      year: _year,
                      month: _monthIndex + 1,
                      day: _day,
                    ),
                  ),
                  child: const Text('Select'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
