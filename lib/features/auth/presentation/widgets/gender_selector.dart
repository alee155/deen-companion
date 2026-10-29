import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/entities/gender.dart';

/// Male / Female, as two side-by-side choices. Nothing is selected until the
/// user picks: the backend needs an answer, and a default would put a guess
/// on the account that can never be corrected.
class GenderSelector extends StatelessWidget {
  final Gender? value;
  final ValueChanged<Gender> onChanged;
  final String? errorText;
  final bool enabled;

  const GenderSelector({
    super.key,
    required this.value,
    required this.onChanged,
    this.errorText,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Gender',
          style: AppTypography.bodyMedium.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.inkText,
          ),
        ),
        SizedBox(height: 6.h),
        Row(
          children: [
            for (final g in Gender.values) ...[
              Expanded(
                child: _Choice(
                  gender: g,
                  selected: value == g,
                  enabled: enabled,
                  onTap: () => onChanged(g),
                ),
              ),
              if (g != Gender.values.last) SizedBox(width: 10.w),
            ],
          ],
        ),
        if (errorText != null) ...[
          SizedBox(height: 4.h),
          Text(
            errorText!,
            style: TextStyle(fontSize: 12.sp, color: AppColors.error),
          ),
        ],
      ],
    );
  }
}

class _Choice extends StatelessWidget {
  final Gender gender;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  const _Choice({
    required this.gender,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final icon = gender == Gender.male
        ? Icons.male_rounded
        : Icons.female_rounded;
    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      label: gender.label,
      excludeSemantics: true,
      child: Material(
        color: selected
            ? AppColors.emeraldInk.withValues(alpha: 0.14)
            : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(16.r),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? onTap : null,
          child: Container(
            height: 52.h,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(
                color: selected ? AppColors.emeraldInk : AppColors.borderWarm,
                width: selected ? 1.6 : 1,
              ),
            ),
            // Scales down rather than overflow, on a narrow screen or with
            // large text.
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 20.sp,
                    color: selected
                        ? AppColors.emeraldInk
                        : AppColors.textMuted,
                  ),
                  SizedBox(width: 6.w),
                  Text(
                    gender.label,
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                      color: AppColors.inkText,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
