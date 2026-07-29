import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';

class ZakatAssetInputSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool checked;
  final ValueChanged<bool> onCheckedChanged;
  final List<Widget> fields;

  const ZakatAssetInputSection({
    super.key,
    required this.title,
    required this.icon,
    required this.checked,
    required this.onCheckedChanged,
    required this.fields,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: AppColors.borderWarm),
      ),
      child: Column(
        children: [
          CheckboxListTile(
            value: checked,
            onChanged: (v) => onCheckedChanged(v ?? false),
            activeColor: AppColors.emeraldInk,
            controlAffinity: ListTileControlAffinity.leading,
            secondary: Icon(icon, color: AppColors.toolsAccent, size: 20.sp),
            title: Text(
              title,
              style: AppTypography.titleMedium.copyWith(
                color: AppColors.inkText,
              ),
            ),
          ),
          if (checked)
            Padding(
              padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 14.h),
              child: Column(children: fields),
            ),
        ],
      ),
    );
  }
}
