import 'package:flutter/material.dart';
import 'package:deen_companion/core/motion/motion.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/app_colors.dart';

class FormSectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;
  const FormSectionTitle({
    super.key,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 17.sp,
            fontWeight: FontWeight.w700,
            color: AppColors.inkText,
          ),
        ),
        SizedBox(height: 3.h),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 12.5.sp,
            height: 1.4,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

InputDecoration groupInputDecoration({
  required String label,
  required String hint,
  required IconData icon,
  bool alignLabelWithHint = false,
}) {
  OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(18.r),
    borderSide: BorderSide(color: c, width: w),
  );
  return InputDecoration(
    labelText: label,
    hintText: hint,
    alignLabelWithHint: alignLabelWithHint,
    prefixIcon: Icon(icon, color: AppColors.gold, size: 21.sp),
    labelStyle: TextStyle(color: AppColors.textSecondary, fontSize: 13.sp),
    hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 13.sp),
    counterStyle: TextStyle(color: AppColors.textMuted, fontSize: 11.sp),
    filled: true,
    fillColor: AppColors.surfaceLight,
    contentPadding: EdgeInsets.symmetric(horizontal: 15.w, vertical: 16.h),
    border: border(AppColors.borderWarm),
    enabledBorder: border(AppColors.borderWarm),
    focusedBorder: border(AppColors.gold, 1.6),
    errorBorder: border(AppColors.error),
    focusedErrorBorder: border(AppColors.error, 1.6),
  );
}

class ApprovalToggleCard extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  const ApprovalToggleCard({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(22.r),
        border: Border.all(color: AppColors.borderWarm),
      ),
      child: Row(
        children: [
          Container(
            width: 42.w,
            height: 42.w,
            decoration: BoxDecoration(
              color: AppColors.toolsAccentBg,
              borderRadius: BorderRadius.circular(14.r),
            ),
            child: Icon(
              Icons.verified_user_rounded,
              size: 20.sp,
              color: AppColors.toolsAccent,
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Admin approval',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.inkText,
                  ),
                ),
                Text(
                  'Approve new members before they join.',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.heroSurface,
            activeTrackColor: AppColors.gold,
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet that asks where the group photo should come from.
Future<ImageSource?> showImageSourceSheet(BuildContext context) {
  Widget option(
    BuildContext ctx,
    IconData icon,
    String title,
    String subtitle,
    ImageSource source,
  ) {
    return PressScale(
      child: InkWell(
        borderRadius: BorderRadius.circular(20.r),
        onTap: () => Navigator.of(ctx).pop(source),
        child: Container(
          padding: EdgeInsets.all(14.w),
          decoration: BoxDecoration(
            color: AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(20.r),
            border: Border.all(color: AppColors.borderWarm),
          ),
          child: Row(
            children: [
              Container(
                width: 44.w,
                height: 44.w,
                decoration: BoxDecoration(
                  color: AppColors.heroSurface,
                  borderRadius: BorderRadius.circular(14.r),
                ),
                child: Icon(icon, size: 22.sp, color: AppColors.goldLight),
              ),
              SizedBox(width: 14.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w700,
                        color: AppColors.inkText,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }

  return showModalBottomSheet<ImageSource>(
    sheetAnimationStyle: AppMotion.sheetStyle,
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Container(
      padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 12.h),
      decoration: BoxDecoration(
        color: AppColors.parchment,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: AppColors.borderWarm,
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
            SizedBox(height: 16.h),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Group photo',
                style: TextStyle(
                  fontSize: 20.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.inkText,
                ),
              ),
            ),
            SizedBox(height: 14.h),
            option(
              ctx,
              Icons.photo_library_rounded,
              'Choose from gallery',
              'Select an image from your device',
              ImageSource.gallery,
            ),
            SizedBox(height: 10.h),
            option(
              ctx,
              Icons.camera_alt_rounded,
              'Take a photo',
              'Use your camera',
              ImageSource.camera,
            ),
            SizedBox(height: 8.h),
          ],
        ),
      ),
    ),
  );
}
