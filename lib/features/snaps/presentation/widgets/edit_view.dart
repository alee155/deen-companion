import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import 'snap_chrome.dart';
import 'snap_timer_selector.dart';

/// Step 3: preview the final image, set the view timer, add a caption.
class EditView extends StatefulWidget {
  final Uint8List image;
  final int viewSeconds;
  final String caption;
  final bool isProcessing;
  final String? errorMessage;
  final VoidCallback onRetake;
  final VoidCallback onRecrop;
  final ValueChanged<int> onTimerChanged;
  final ValueChanged<String> onCaptionChanged;
  final VoidCallback onNext;

  const EditView({
    super.key,
    required this.image,
    required this.viewSeconds,
    required this.caption,
    required this.isProcessing,
    required this.errorMessage,
    required this.onRetake,
    required this.onRecrop,
    required this.onTimerChanged,
    required this.onCaptionChanged,
    required this.onNext,
  });

  static const maxCaption = 80;

  @override
  State<EditView> createState() => _EditViewState();
}

class _EditViewState extends State<EditView> {
  late final _caption = TextEditingController(text: widget.caption);

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final captionText = _caption.text.trim();
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
                    onPressed: widget.isProcessing ? null : widget.onRetake,
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        'Preview',
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
                    onPressed: widget.isProcessing ? null : widget.onRecrop,
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
                    child: Stack(
                      alignment: Alignment.bottomCenter,
                      children: [
                        Image.memory(
                          widget.image,
                          fit: BoxFit.contain,
                          gaplessPlayback: true,
                        ),
                        if (captionText.isNotEmpty)
                          Positioned(
                            left: 12.w,
                            right: 12.w,
                            bottom: 14.h,
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 12.w,
                                vertical: 8.h,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.55),
                                borderRadius: BorderRadius.circular(14.r),
                              ),
                              child: Text(
                                captionText,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        Positioned(
                          top: 12.h,
                          right: 12.w,
                          child: SnapPill(
                            icon: Icons.hourglass_bottom_rounded,
                            text: '${widget.viewSeconds}s',
                            gold: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(20.w, 14.h, 20.w, 0),
              child: Column(
                children: [
                  TextField(
                    controller: _caption,
                    maxLength: EditView.maxCaption,
                    textCapitalization: TextCapitalization.sentences,
                    style: TextStyle(fontSize: 14.sp, color: Colors.white),
                    onChanged: (v) {
                      setState(() {});
                      widget.onCaptionChanged(v);
                    },
                    decoration: InputDecoration(
                      hintText: 'Add a caption (optional)',
                      hintStyle: TextStyle(
                        fontSize: 14.sp,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                      counterStyle: TextStyle(
                        fontSize: 10.sp,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                      prefixIcon: Icon(
                        Icons.notes_rounded,
                        size: 20.sp,
                        color: AppColors.emeraldInk,
                      ),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.1),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 14.w,
                        vertical: 12.h,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16.r),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16.r),
                        borderSide: BorderSide(
                          color: AppColors.emeraldInk,
                          width: 1.4,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 10.h),
                  SnapTimerSelector(
                    seconds: widget.viewSeconds,
                    onChanged: widget.onTimerChanged,
                  ),
                  if (widget.errorMessage != null) ...[
                    SizedBox(height: 8.h),
                    Text(
                      widget.errorMessage!,
                      style: TextStyle(fontSize: 12.sp, color: AppColors.error),
                    ),
                  ],
                  SizedBox(height: 14.h),
                  SizedBox(
                    width: double.infinity,
                    height: 50.h,
                    child: FilledButton.icon(
                      onPressed: widget.isProcessing ? null : widget.onNext,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.emeraldInk,
                        foregroundColor: AppColors.onEmeraldInk,
                        disabledBackgroundColor: AppColors.emeraldInk,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18.r),
                        ),
                      ),
                      icon: widget.isProcessing
                          ? SizedBox(
                              width: 18.w,
                              height: 18.w,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.onEmeraldInk,
                              ),
                            )
                          : const Icon(Icons.arrow_forward_rounded),
                      label: Text(
                        widget.isProcessing ? 'Preparing…' : 'Next',
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
