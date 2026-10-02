import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';

/// The ornamental 8-point seal badge used for numbering throughout the
/// reader — the same art the Surah list uses for its surah numbers, reused
/// here so ayah and hadith numbers read as one consistent design language
/// rather than each screen inventing its own badge shape.
class SealNumberBadge extends StatelessWidget {
  final int number;
  final double? size;

  /// Tint for the seal outline. Defaults to the brand orange used for Quran
  /// and Hadith numbering — pass a feature's own accent (e.g. `hijriAccent`)
  /// so the badge shape stays consistent app-wide without forcing every
  /// feature into the same hue.
  final Color? color;

  const SealNumberBadge({
    super.key,
    required this.number,
    this.size,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final side = size ?? 42.w;
    return SizedBox(
      width: side,
      height: side,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Image.asset(
            'assets/images/suraah_design.png',
            fit: BoxFit.cover,
            color: color ?? AppColors.emeraldInk,
            width: side,
            height: side,
          ),
          Text(
            '$number',
            maxLines: 1,
            style: AppTypography.titleMedium.copyWith(
              // The badge art is a hollow outline, not a filled shape — the
              // page background (not the badge tint) shows through its
              // center, so the number needs to contrast with that instead.
              color: AppColors.inkText,
              // Some collections run past 999 — a 4-digit number needs a
              // smaller face to still clear the seal's inner points.
              fontSize: number > 999 ? 11.sp : null,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
