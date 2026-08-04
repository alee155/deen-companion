import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/theme_mode_provider.dart';
import 'ornament_divider.dart';
import '../providers/reading_preferences_provider.dart';

/// Reading controls, in a sheet rather than a settings screen so adjustments
/// happen with the text still visible behind them — every change applies to
/// the page underneath immediately, no confirm step.
Future<void> showReaderSettingsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.35),
    builder: (context) => const _ReaderSettingsSheet(),
  );
}

class _ReaderSettingsSheet extends ConsumerWidget {
  const _ReaderSettingsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(readingPreferencesProvider);
    final notifier = ref.read(readingPreferencesProvider.notifier);
    final themeChoice = ref.watch(themeModeNotifierProvider);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
        border: Border(top: BorderSide(color: AppColors.borderWarm)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20.w, 10.h, 20.w, 20.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 38.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: AppColors.borderWarm,
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
              ),
              SizedBox(height: 16.h),
              Row(
                children: [
                  Icon(
                    Icons.text_fields_rounded,
                    size: 18.sp,
                    color: AppColors.emeraldInk,
                  ),
                  SizedBox(width: 8.w),
                  Text(
                    'Reading settings',
                    style: AppTypography.headline.copyWith(
                      fontSize: 16.sp,
                      color: AppColors.inkText,
                    ),
                  ),
                  const Spacer(),
                  if (!prefs.isDefault)
                    TextButton(
                      onPressed: notifier.reset,
                      style: TextButton.styleFrom(
                        minimumSize: Size(48.w, 40.h),
                      ),
                      child: const Text('Reset'),
                    ),
                ],
              ),
              SizedBox(height: 8.h),

              _ScaleSlider(
                label: 'Arabic size',
                valueLabel: prefs.arabicLabel,
                scale: prefs.arabicScale,
                accent: AppColors.emeraldInk,
                sampleText: 'إِنَّمَا الْأَعْمَالُ بِالنِّيَّاتِ',
                sampleStyle: prefs.arabicStyle.copyWith(
                  color: AppColors.inkText,
                  height: 1.9,
                ),
                sampleDirection: TextDirection.rtl,
                onChanged: notifier.setArabicScale,
              ),
              SizedBox(height: 6.h),
              _ScaleSlider(
                label: 'Translation size',
                valueLabel: prefs.englishLabel,
                scale: prefs.englishScale,
                accent: AppColors.quranAccent,
                sampleText: 'The reward of deeds depends upon the intentions.',
                sampleStyle: prefs.englishStyle.copyWith(
                  color: AppColors.textSecondary,
                ),
                onChanged: notifier.setEnglishScale,
              ),

              SizedBox(height: 14.h),
              OrnamentDivider(),
              SizedBox(height: 6.h),

              _ToggleRow(
                icon: Icons.language_rounded,
                label: 'Show Arabic',
                value: prefs.showArabic,
                // The last visible block can't be switched off — that would
                // leave an empty page.
                onChanged: prefs.showTranslation
                    ? notifier.setShowArabic
                    : null,
              ),
              _ToggleRow(
                icon: Icons.translate_rounded,
                label: 'Show translation',
                value: prefs.showTranslation,
                onChanged: prefs.showArabic
                    ? notifier.setShowTranslation
                    : null,
              ),
              _ToggleRow(
                icon: themeChoice == AppThemeChoice.dark
                    ? Icons.dark_mode_rounded
                    : Icons.light_mode_rounded,
                label: 'Dark reading mode',
                value: themeChoice == AppThemeChoice.dark,
                onChanged: (enabled) => ref
                    .read(themeModeNotifierProvider.notifier)
                    .setChoice(
                      enabled ? AppThemeChoice.dark : AppThemeChoice.light,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScaleSlider extends StatelessWidget {
  final String label;
  final String valueLabel;
  final double scale;
  final Color accent;
  final String sampleText;
  final TextStyle sampleStyle;
  final TextDirection? sampleDirection;
  final ValueChanged<double> onChanged;

  const _ScaleSlider({
    required this.label,
    required this.valueLabel,
    required this.scale,
    required this.accent,
    required this.sampleText,
    required this.sampleStyle,
    required this.onChanged,
    this.sampleDirection,
  });

  void _step(int direction) {
    const range = ReadingPreferences.maxScale - ReadingPreferences.minScale;
    const step = range / ReadingPreferences.scaleDivisions;
    onChanged(
      (scale + step * direction).clamp(
        ReadingPreferences.minScale,
        ReadingPreferences.maxScale,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: AppTypography.titleMedium.copyWith(
                color: AppColors.inkText,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(width: 8.w),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6.r),
              ),
              child: Text(
                valueLabel,
                style: AppTypography.caption.copyWith(
                  color: accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        Row(
          children: [
            // Explicit −/+ buttons alongside the slider: far easier than a
            // drag for anyone with limited dexterity, and each is a full
            // 44dp target.
            _StepButton(
              icon: Icons.remove_rounded,
              tooltip: 'Smaller $label',
              onPressed: scale > ReadingPreferences.minScale
                  ? () => _step(-1)
                  : null,
            ),
            Expanded(
              child: Slider(
                value: scale,
                min: ReadingPreferences.minScale,
                max: ReadingPreferences.maxScale,
                divisions: ReadingPreferences.scaleDivisions,
                label: valueLabel,
                activeColor: accent,
                inactiveColor: AppColors.borderWarm,
                onChanged: onChanged,
              ),
            ),
            _StepButton(
              icon: Icons.add_rounded,
              tooltip: 'Larger $label',
              onPressed: scale < ReadingPreferences.maxScale
                  ? () => _step(1)
                  : null,
            ),
          ],
        ),
        // Live preview, so the size is chosen against real text instead of a
        // number.
        Padding(
          padding: EdgeInsets.only(bottom: 4.h),
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            style: sampleStyle,
            child: Text(
              sampleText,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textDirection: sampleDirection,
              textAlign: sampleDirection == TextDirection.rtl
                  ? TextAlign.right
                  : TextAlign.left,
            ),
          ),
        ),
      ],
    );
  }
}

class _StepButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  const _StepButton({
    required this.icon,
    required this.tooltip,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      iconSize: 18.sp,
      constraints: BoxConstraints(minWidth: 44.w, minHeight: 44.h),
      style: IconButton.styleFrom(
        backgroundColor: AppColors.parchment,
        foregroundColor: AppColors.inkText,
        disabledForegroundColor: AppColors.textMuted,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10.r),
          side: BorderSide(color: AppColors.borderWarm),
        ),
      ),
      icon: Icon(icon),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;

  const _ToggleRow({
    required this.icon,
    required this.label,
    required this.value,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onChanged != null;
    return SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      value: value,
      onChanged: onChanged,
      activeThumbColor: AppColors.emeraldInk,
      secondary: Icon(
        icon,
        size: 20.sp,
        color: enabled ? AppColors.inkText : AppColors.textMuted,
      ),
      title: Text(
        label,
        style: AppTypography.bodyLarge.copyWith(
          color: enabled ? AppColors.inkText : AppColors.textMuted,
        ),
      ),
    );
  }
}
