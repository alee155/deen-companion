import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../core/theme/app_colors.dart';
import '../domain/translation_language.dart';

/// Says that a translation isn't there, in the place the translation would
/// have been — instead of quietly showing the other language.
///
/// [onRetry] is for the case where it might be there but couldn't be loaded
/// (offline): the message then says so and can be tapped to try again.
class TranslationUnavailable extends StatelessWidget {
  final TranslationLanguage language;

  /// The text size to match the surrounding text.
  final double? fontSize;

  /// Set when the translation failed to load rather than not existing.
  final VoidCallback? onRetry;

  const TranslationUnavailable({
    super.key,
    this.language = TranslationLanguage.urdu,
    this.fontSize,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final failed = onRetry != null;
    final message = failed
        ? 'Couldn’t load the ${language.label} translation. Tap to retry.'
        : language.unavailableMessage;
    final size = fontSize ?? 13.sp;

    final row = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(top: 1.h),
          child: Icon(
            failed ? Icons.refresh_rounded : Icons.info_outline_rounded,
            size: size + 2,
            color: AppColors.textMuted,
          ),
        ),
        SizedBox(width: 6.w),
        Flexible(
          child: Text(
            message,
            style: TextStyle(
              fontSize: size,
              fontStyle: FontStyle.italic,
              color: AppColors.textMuted,
              height: 1.4,
            ),
          ),
        ),
      ],
    );

    return Semantics(
      label: message,
      button: failed,
      child: failed ? InkWell(onTap: onRetry, child: row) : row,
    );
  }
}
