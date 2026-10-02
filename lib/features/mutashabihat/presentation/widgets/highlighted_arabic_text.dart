import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../utils/arabic_diff.dart';

/// Renders a verse's diff tokens as one RTL paragraph, with the words that
/// make it diverge from its lookalike picked out in amber — the actual
/// point of comparison, not just two blocks of look-alike text stacked on
/// top of each other.
class HighlightedArabicText extends StatelessWidget {
  final List<DiffToken> tokens;
  final TextStyle style;

  const HighlightedArabicText({
    super.key,
    required this.tokens,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    final highlightStyle = style.copyWith(
      color: AppColors.amberDeep,
      fontWeight: FontWeight.w800,
      backgroundColor: AppColors.amber.withValues(alpha: 0.22),
    );

    return SelectableText.rich(
      TextSpan(
        children: [
          for (var i = 0; i < tokens.length; i++) ...[
            TextSpan(
              text: tokens[i].text,
              style: tokens[i].changed ? highlightStyle : style,
            ),
            if (i != tokens.length - 1) TextSpan(text: ' ', style: style),
          ],
        ],
      ),
      textDirection: TextDirection.rtl,
      textAlign: TextAlign.right,
    );
  }
}

/// A small legend explaining the highlight, shown once per comparison screen
/// rather than repeated on every card.
class DiffLegend extends StatelessWidget {
  const DiffLegend({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12.w,
          height: 12.w,
          decoration: BoxDecoration(
            color: AppColors.amber.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(3.r),
            border: Border.all(
              color: AppColors.amberDeep.withValues(alpha: 0.5),
            ),
          ),
        ),
        SizedBox(width: 6.w),
        Text(
          'Highlighted words are where the verses differ',
          style: TextStyle(fontSize: 11.5.sp, color: AppColors.textMuted),
        ),
      ],
    );
  }
}
