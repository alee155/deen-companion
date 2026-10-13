import 'dart:typed_data';
import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import 'snap_chrome.dart';

/// Step 2: crop. Aspect presets make common shapes one tap.
class CropView extends StatefulWidget {
  final Uint8List image;
  final ValueChanged<Uint8List> onCropped;
  final VoidCallback onBack;

  const CropView({
    super.key,
    required this.image,
    required this.onCropped,
    required this.onBack,
  });

  @override
  State<CropView> createState() => _CropViewState();
}

class _CropViewState extends State<CropView> {
  static const _ratios = <(String, double?)>[
    ('Free', null),
    ('Square', 1),
    ('Portrait', 4 / 5),
    ('Tall', 9 / 16),
  ];

  final _controller = CropController();
  int _selected = 0;
  bool _cropping = false;
  bool _canUndo = false;
  String? _error;

  void _pick(int i) {
    HapticFeedback.selectionClick();
    setState(() => _selected = i);
    _controller.aspectRatio = _ratios[i].$2;
  }

  void _done() {
    setState(() {
      _cropping = true;
      _error = null;
    });
    _controller.crop();
  }

  @override
  Widget build(BuildContext context) {
    return SnapBackdrop(
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 0),
              child: Row(
                children: [
                  SnapRoundButton(
                    icon: Icons.arrow_back_rounded,
                    tooltip: 'Retake',
                    onPressed: _cropping ? null : widget.onBack,
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        'Crop',
                        style: TextStyle(
                          fontSize: 17.sp,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  SnapRoundButton(
                    icon: Icons.undo_rounded,
                    tooltip: 'Undo',
                    onPressed: _canUndo && !_cropping ? _controller.undo : null,
                  ),
                ],
              ),
            ),
            SizedBox(height: 8.h),
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 12.w),
                child: Crop(
                  image: widget.image,
                  controller: _controller,
                  baseColor: Colors.black,
                  maskColor: Colors.black.withValues(alpha: 0.62),
                  radius: 10,
                  progressIndicator: CircularProgressIndicator(
                    color: AppColors.emeraldInk,
                  ),
                  cornerDotBuilder: (size, edge) =>
                      DotControl(color: AppColors.emeraldInk),
                  onHistoryChanged: (h) {
                    final can = h.undoCount > 0;
                    if (can != _canUndo) setState(() => _canUndo = can);
                  },
                  onCropped: (result) {
                    switch (result) {
                      case CropSuccess(:final croppedImage):
                        widget.onCropped(croppedImage);
                      case CropFailure():
                        if (mounted) {
                          setState(() {
                            _cropping = false;
                            _error = 'Couldn’t crop the photo. Try again.';
                          });
                        }
                    }
                  },
                ),
              ),
            ),
            SizedBox(height: 14.h),
            if (_error != null)
              Padding(
                padding: EdgeInsets.only(bottom: 8.h),
                child: Text(
                  _error!,
                  style: TextStyle(fontSize: 12.sp, color: AppColors.error),
                ),
              ),
            SizedBox(
              height: 40.h,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                itemCount: _ratios.length,
                separatorBuilder: (_, _) => SizedBox(width: 8.w),
                itemBuilder: (_, i) => GestureDetector(
                  onTap: _cropping ? null : () => _pick(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    padding: EdgeInsets.symmetric(horizontal: 16.w),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16.r),
                      color: i == _selected
                          ? AppColors.emeraldInk
                          : Colors.white.withValues(alpha: 0.1),
                      border: Border.all(
                        color: i == _selected
                            ? AppColors.emeraldInk
                            : Colors.white.withValues(alpha: 0.18),
                      ),
                    ),
                    child: Text(
                      _ratios[i].$1,
                      style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w700,
                        color: i == _selected
                            ? AppColors.onEmeraldInk
                            : Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: 14.h),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w),
              child: SizedBox(
                width: double.infinity,
                height: 50.h,
                child: FilledButton.icon(
                  onPressed: _cropping ? null : _done,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.emeraldInk,
                    foregroundColor: AppColors.onEmeraldInk,
                    disabledBackgroundColor: AppColors.emeraldInk,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18.r),
                    ),
                  ),
                  icon: _cropping
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
                    _cropping ? 'Cropping…' : 'Done',
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: 14.h),
          ],
        ),
      ),
    );
  }
}
