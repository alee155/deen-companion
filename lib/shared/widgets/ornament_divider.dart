import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../core/theme/app_colors.dart';

/// A hairline rule interrupted by a small rotated square — the quiet
/// geometric motif that separates sections in the reader.
///
/// Deliberately drawn rather than an asset: it takes its colour from the
/// active palette, so it stays a whisper in Light and doesn't glow in Dark.
class OrnamentDivider extends StatelessWidget {
  final Color? color;

  /// Width of the rules either side of the diamond. Null stretches to fill.
  final double? ruleWidth;

  const OrnamentDivider({super.key, this.color, this.ruleWidth});

  @override
  Widget build(BuildContext context) {
    final lineColor = color ?? AppColors.borderWarm;
    final diamondColor = color ?? AppColors.gold;

    Widget rule() {
      final line = Container(height: 1, color: lineColor);
      return ruleWidth == null
          ? Expanded(child: line)
          : SizedBox(width: ruleWidth, child: line);
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        rule(),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 10.w),
          child: Transform.rotate(
            angle: 0.785398, // 45°
            child: Container(
              width: 6.w,
              height: 6.w,
              decoration: BoxDecoration(
                color: diamondColor,
                borderRadius: BorderRadius.circular(1.r),
              ),
            ),
          ),
        ),
        rule(),
      ],
    );
  }
}
