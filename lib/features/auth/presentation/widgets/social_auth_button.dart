import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/theme/app_typography.dart';

/// A full-width "Continue with …" button: a brand icon and a label in a pill.
/// [GoogleButton] and [AppleButton] only choose the look.
class SocialAuthButton extends StatelessWidget {
  final String label;

  /// SVG asset of the brand mark.
  final String iconAsset;

  /// Null disables the button (another sign-in is under way).
  final VoidCallback? onPressed;
  final Color backgroundColor;
  final Color foregroundColor;

  /// The pill's outline; null for none.
  final Color? borderColor;

  /// Paints the icon in [foregroundColor] (for a one-colour mark on a dark
  /// button). Off keeps the icon's own colours.
  final bool tintIcon;

  /// Shows a spinner in place of the icon while this provider's sheet or
  /// request is open.
  final bool loading;

  const SocialAuthButton({
    super.key,
    required this.label,
    required this.iconAsset,
    required this.onPressed,
    required this.backgroundColor,
    required this.foregroundColor,
    this.borderColor,
    this.tintIcon = false,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52.h,
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: backgroundColor,
          side: borderColor == null
              ? BorderSide.none
              : BorderSide(color: borderColor!, width: 1.w),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30.r),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (loading)
              SizedBox(
                height: 22.h,
                width: 22.h,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: foregroundColor,
                ),
              )
            else
              SvgPicture.asset(
                iconAsset,
                height: 22.h,
                width: 22.h,
                colorFilter: tintIcon
                    ? ColorFilter.mode(foregroundColor, BlendMode.srcIn)
                    : null,
                // The label already names it; the icon is decoration.
                excludeFromSemantics: true,
              ),
            SizedBox(width: 10.w),
            Text(
              label,
              style: AppTypography.bodyLarge.copyWith(
                color: foregroundColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
