import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../providers/islamic_calendar_providers.dart';
import '../widgets/hijri_date_picker_sheet.dart';

enum _Direction { gregorianToHijri, hijriToGregorian }

class DateConverterScreen extends ConsumerStatefulWidget {
  const DateConverterScreen({super.key});

  @override
  ConsumerState<DateConverterScreen> createState() =>
      _DateConverterScreenState();
}

class _DateConverterScreenState extends ConsumerState<DateConverterScreen> {
  _Direction _direction = _Direction.gregorianToHijri;
  DateTime? _pickedGregorian;
  HijriPickedDate? _pickedHijri;

  Future<void> _pickGregorian() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _pickedGregorian = picked);
      ref
          .read(dateConverterNotifierProvider.notifier)
          .convertGregorianToHijri(picked);
    }
  }

  Future<void> _pickHijri() async {
    final picked = await showHijriDatePicker(context, initialYear: 1447);
    if (picked != null) {
      setState(() => _pickedHijri = picked);
      ref
          .read(dateConverterNotifierProvider.notifier)
          .convertHijriToGregorian(picked.year, picked.month, picked.day);
    }
  }

  @override
  Widget build(BuildContext context) {
    final resultAsync = ref.watch(dateConverterNotifierProvider);

    return Scaffold(
      backgroundColor: AppColors.parchment,
      appBar: AppBar(
        title: const Text('Date Converter'),
        backgroundColor: AppColors.surfaceLight,
        foregroundColor: AppColors.inkText,
      ),
      body: Padding(
        padding: EdgeInsets.all(20.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.all(4.w),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: AppColors.borderWarm),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _DirectionTab(
                      label: 'Gregorian → Hijri',
                      selected: _direction == _Direction.gregorianToHijri,
                      onTap: () => setState(
                        () => _direction = _Direction.gregorianToHijri,
                      ),
                    ),
                  ),
                  Expanded(
                    child: _DirectionTab(
                      label: 'Hijri → Gregorian',
                      selected: _direction == _Direction.hijriToGregorian,
                      onTap: () => setState(
                        () => _direction = _Direction.hijriToGregorian,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 20.h),
            GestureDetector(
              onTap: _direction == _Direction.gregorianToHijri
                  ? _pickGregorian
                  : _pickHijri,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(color: AppColors.borderWarm),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_today_outlined,
                      color: AppColors.hijriAccent,
                      size: 18.sp,
                    ),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: Text(
                        _direction == _Direction.gregorianToHijri
                            ? (_pickedGregorian == null
                                  ? 'Select a Gregorian date'
                                  : '${_pickedGregorian!.year}-${_pickedGregorian!.month}-${_pickedGregorian!.day}')
                            : (_pickedHijri == null
                                  ? 'Select a Hijri date'
                                  : '${_pickedHijri!.year}-${_pickedHijri!.month}-${_pickedHijri!.day} AH'),
                        style: AppTypography.bodyLarge.copyWith(
                          color: AppColors.inkText,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.keyboard_arrow_down,
                      color: AppColors.textSecondary,
                      size: 18.sp,
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 24.h),
            resultAsync.when(
              data: (result) {
                if (result == null) return const SizedBox.shrink();
                return Container(
                  padding: EdgeInsets.all(20.w),
                  decoration: BoxDecoration(
                    color: AppColors.hijriAccent,
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Result',
                        style: AppTypography.caption.copyWith(
                          color: Colors.white70,
                        ),
                      ),
                      SizedBox(height: 8.h),
                      Text(
                        result.hijri.formatted,
                        style: AppTypography.titleMedium.copyWith(
                          color: Colors.white,
                          fontSize: 18.sp,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        result.gregorian.formatted,
                        style: AppTypography.bodyMedium.copyWith(
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Text(error.toString()),
            ),
          ],
        ),
      ),
    );
  }
}

class _DirectionTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _DirectionTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
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
