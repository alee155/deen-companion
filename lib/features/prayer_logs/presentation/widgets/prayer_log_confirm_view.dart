import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../snaps/presentation/widgets/snap_chrome.dart';

/// Last step before upload: look at the photo, then log the prayer.
class PrayerLogConfirmView extends StatelessWidget {
  final Uint8List image;

  /// "Asr" — only a label: the server decides which prayer this counts for.
  final String? prayerLabel;
  final bool isProcessing;
  final bool isSubmitting;
  final String? errorMessage;
  final VoidCallback onRetake;
  final VoidCallback onRecrop;
  final VoidCallback onSubmit;

  const PrayerLogConfirmView({
    super.key,
    required this.image,
    required this.prayerLabel,
    required this.isProcessing,
    required this.isSubmitting,
    required this.errorMessage,
    required this.onRetake,
    required this.onRecrop,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final busy = isProcessing || isSubmitting;
    return SnapBackdrop(
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 0),
              child: Row(
                children: [
                  SnapRoundButton(
                    icon: Icons.refresh_rounded,
                    tooltip: 'Retake photo',
                    onPressed: busy ? null : onRetake,
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        'Confirm',
                        style: TextStyle(
                          fontSize: 17.sp,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  SnapRoundButton(
                    icon: Icons.crop_rounded,
                    tooltip: 'Crop again',
                    onPressed: busy ? null : onRecrop,
                  ),
                ],
              ),
            ),
            SizedBox(height: 10.h),
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 14.w),
                child: Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(26.r),
                    child: Image.memory(
                      image,
                      fit: BoxFit.contain,
                      gaplessPlayback: true,
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(20.w, 14.h, 20.w, 0),
              child: Column(
                children: [
                  if (errorMessage != null) ...[
                    Text(
                      errorMessage!,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12.sp, color: AppColors.error),
                    ),
                    SizedBox(height: 10.h),
                  ],
                  SizedBox(
                    width: double.infinity,
                    height: 50.h,
                    child: FilledButton.icon(
                      onPressed: (isProcessing || isSubmitting)
                          ? null
                          : onSubmit,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.emeraldInk,
                        foregroundColor: AppColors.onEmeraldInk,
                        disabledBackgroundColor: AppColors.emeraldInk,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18.r),
                        ),
                      ),
                      icon: busy
                          ? SizedBox(
                              width: 18.w,
                              height: 18.w,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.onEmeraldInk,
                              ),
                            )
                          : const Icon(Icons.check_rounded),
                      label: Text(
                        isSubmitting
                            ? 'Logging…'
                            : isProcessing
                            ? 'Preparing…'
                            : prayerLabel == null
                            ? 'Log prayer'
                            : 'Log $prayerLabel',
                        style: TextStyle(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 14.h),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
