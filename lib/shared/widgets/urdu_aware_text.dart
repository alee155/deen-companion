import 'package:flutter/material.dart';

/// The Urdu face used wherever Urdu is read.
const kUrduFontFamily = 'NotoNastaliqUrdu';

/// [base] drawn in Urdu: the Nastaliq face, with the extra line height its tall
/// strokes need.
TextStyle urduTextStyle(TextStyle base, {double height = 2.0}) => base.copyWith(
  fontFamily: kUrduFontFamily,
  height: height,
  letterSpacing: 0,
);

/// Text in the reader's language: Urdu is set right to left in Nastaliq and
/// takes the full width so it sits on the right; anything else is plain.
///
/// Not for a shrink-wrapped parent (a chip, a Row child without `Expanded`):
/// Urdu here fills the width it is given.
class UrduAwareText extends StatelessWidget {
  final String text;
  final bool urdu;
  final TextStyle style;
  final int? maxLines;
  final double urduHeight;
  final TextAlign? align;

  const UrduAwareText(
    this.text, {
    super.key,
    required this.urdu,
    required this.style,
    this.maxLines,
    this.urduHeight = 1.9,
    this.align,
  });

  @override
  Widget build(BuildContext context) {
    final overflow = maxLines == null ? null : TextOverflow.ellipsis;
    if (!urdu) {
      return Text(
        text,
        maxLines: maxLines,
        overflow: overflow,
        textAlign: align,
        style: style,
      );
    }
    return SizedBox(
      width: double.infinity,
      child: Text(
        text,
        maxLines: maxLines,
        overflow: overflow,
        textDirection: TextDirection.rtl,
        textAlign: align ?? TextAlign.right,
        style: urduTextStyle(style, height: urduHeight),
      ),
    );
  }
}
