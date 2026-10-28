import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// A short floating message at the bottom of the screen, the same style as the
/// app's other toasts. [icon] makes a longer explanation easier to notice, and
/// the message stays up long enough to read: about a second per six words,
/// never less than the default.
///
/// Replaces whatever toast is showing, so tapping a disabled button twice
/// doesn't queue the same message.
void showAppToast(BuildContext context, String message, {IconData? icon}) {
  final words = message.split(RegExp(r'\s+')).length;
  final seconds = (words / 6).ceil().clamp(4, 8);
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: seconds),
        content: Semantics(
          liveRegion: true,
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20.sp, color: Colors.white),
                SizedBox(width: 12.w),
              ],
              Expanded(child: Text(message)),
            ],
          ),
        ),
      ),
    );
  // Screen-reader users hear it even if focus is elsewhere.
  SemanticsService.sendAnnouncement(
    View.of(context),
    message,
    Directionality.of(context),
  );
}
