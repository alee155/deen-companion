import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_colors.dart';

/// A prayer-log photo from its signed URL. A failed load (expired signature,
/// offline) shows a placeholder rather than an error.
class SnapPhoto extends StatelessWidget {
  final String url;
  final BoxFit fit;
  const SnapPhoto({super.key, required this.url, this.fit = BoxFit.cover});

  @override
  Widget build(BuildContext context) {
    return Image.network(
      url,
      fit: fit,
      loadingBuilder: (context, child, progress) => progress == null
          ? child
          : ColoredBox(
              color: AppColors.borderWarm,
              child: const Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
      errorBuilder: (context, _, _) => ColoredBox(
        color: AppColors.borderWarm,
        child: Icon(
          Icons.image_not_supported_outlined,
          color: AppColors.textMuted,
          size: 22.sp,
        ),
      ),
    );
  }
}

Future<void> showSnapPhoto(
  BuildContext context, {
  required String url,
  required String title,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      backgroundColor: Colors.black,
      insetPadding: EdgeInsets.all(16.w),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22.r)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(16.w, 8.h, 4.w, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                ),
              ],
            ),
          ),
          Flexible(
            child: InteractiveViewer(
              child: SnapPhoto(url: url, fit: BoxFit.contain),
            ),
          ),
        ],
      ),
    ),
  );
}
