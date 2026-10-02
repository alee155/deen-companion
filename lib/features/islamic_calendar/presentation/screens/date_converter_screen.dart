import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/failure_view.dart';
import '../providers/islamic_calendar_providers.dart';
import '../widgets/hijri_date_picker_sheet.dart';
import '../../../../shared/widgets/deen_app_bar.dart';

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
      appBar: const DeenAppBar(title: 'Date Converter'),
      body: SingleChildScrollView(
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
            ).slideIn(RevealDirection.top, distance: 18),
            SizedBox(height: 20.h),
            Pressable(
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
                      _direction == _Direction.gregorianToHijri
                          ? Icons.calendar_today_outlined
                          : Icons.event_note_outlined,
                      color: AppColors.emeraldInk,
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
            ).slideIn(
              RevealDirection.bottomStart,
              delay: const Duration(milliseconds: 80),
            ),
            SizedBox(height: 24.h),
            ContentSwitcher(
              child: resultAsync.when(
                data: (result) {
                  if (result == null) {
                    return const _ConverterEmptyState(key: ValueKey('empty'));
                  }
                  return Container(
                    key: ValueKey(result.hijri.formatted),
                    width: double.infinity,
                    padding: EdgeInsets.all(20.w),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppColors.emeraldInk,
                          AppColors.emeraldInk.withValues(alpha: 0.82),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(18.r),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      children: [
                        Positioned(
                          right: -14.w,
                          bottom: -14.h,
                          child: Opacity(
                            opacity: 0.14,
                            child: Image.asset(
                              'assets/images/calendar_icon.png',
                              width: 90.w,
                              height: 90.w,
                            ),
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'RESULT',
                              style: AppTypography.caption.copyWith(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.2,
                              ),
                            ),
                            SizedBox(height: 8.h),
                            Text(
                              result.hijri.formatted,
                              style: AppTypography.headline.copyWith(
                                color: Colors.white,
                                fontSize: 19.sp,
                              ),
                            ),
                            SizedBox(height: 4.h),
                            Text(
                              result.gregorian.formatted,
                              style: AppTypography.bodyMedium.copyWith(
                                color: Colors.white.withValues(alpha: 0.85),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
                loading: () => Container(
                  key: const ValueKey('loading'),
                  width: double.infinity,
                  padding: EdgeInsets.all(24.w),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(18.r),
                    border: Border.all(color: AppColors.borderWarm),
                  ),
                  child: SizedBox(
                    width: 22.w,
                    height: 22.w,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: AppColors.emeraldInk,
                    ),
                  ),
                ),
                error: (error, _) => FailureView(
                  key: const ValueKey('error'),
                  failure: failureFrom(error),
                  onRetry: () async {
                    if (_direction == _Direction.gregorianToHijri &&
                        _pickedGregorian != null) {
                      await ref
                          .read(dateConverterNotifierProvider.notifier)
                          .convertGregorianToHijri(_pickedGregorian!);
                    } else if (_pickedHijri != null) {
                      final h = _pickedHijri!;
                      await ref
                          .read(dateConverterNotifierProvider.notifier)
                          .convertHijriToGregorian(h.year, h.month, h.day);
                    }
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConverterEmptyState extends StatelessWidget {
  const _ConverterEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24.w),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: AppColors.borderWarm),
      ),
      child: Column(
        children: [
          Icon(
            Icons.swap_horiz_rounded,
            size: 30.sp,
            color: AppColors.emeraldInk.withValues(alpha: 0.6),
          ),
          SizedBox(height: 10.h),
          Text(
            'Pick a date above to convert it',
            textAlign: TextAlign.center,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
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
    return Pressable(
      haptic: true,
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppMotion.fast,
        curve: AppMotion.entrance,
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
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
