import 'package:flutter/widgets.dart';
import 'package:share_plus/share_plus.dart';

/// Shares [text] through the system share sheet.
///
/// On iPad the sheet is a popover and share_plus needs a rectangle to anchor
/// it to; without one the call fails. The anchor is the widget [context]
/// belongs to, or the middle of the screen if that can't be measured. iPhone
/// and Android ignore it.
Future<void> shareText(BuildContext context, String text, {String? subject}) {
  Rect? origin;
  final box = context.findRenderObject();
  if (box is RenderBox && box.attached && box.hasSize && !box.size.isEmpty) {
    origin = box.localToGlobal(Offset.zero) & box.size;
  }
  origin ??= Rect.fromCenter(
    center: MediaQuery.sizeOf(context).center(Offset.zero),
    width: 1,
    height: 1,
  );
  return Share.share(text, subject: subject, sharePositionOrigin: origin);
}
