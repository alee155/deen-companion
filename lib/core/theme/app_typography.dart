import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// UI typography scale. Serif is reserved for moments that should feel
/// considered — greetings, hero numbers, section titles that carry weight.
/// Everything functional (labels, buttons, list content) stays sans.
/// Arabic text uses its own typeface, applied directly where Arabic
/// strings are rendered, not defined here.
class AppTypography {
  AppTypography._();

  static const String sansFamily = 'Manrope';
  static const String serifFamily =
      'Georgia'; // swap for a licensed serif asset (e.g. Fraunces) when available

  static TextStyle get heroSerif => TextStyle(
    fontFamily: serifFamily,
    fontSize: 32.sp,
    fontWeight: FontWeight.w400,
    height: 1.2,
  );

  static TextStyle get greetingSerif => TextStyle(
    fontFamily: serifFamily,
    fontSize: 20.sp,
    fontWeight: FontWeight.w400,
    height: 1.3,
  );

  static TextStyle get headline => TextStyle(
    fontFamily: sansFamily,
    fontSize: 18.sp,
    fontWeight: FontWeight.w600,
    height: 1.3,
  );

  static TextStyle get titleMedium => TextStyle(
    fontFamily: sansFamily,
    fontSize: 14.sp,
    fontWeight: FontWeight.w500,
    height: 1.4,
  );

  static TextStyle get bodyLarge => TextStyle(
    fontFamily: sansFamily,
    fontSize: 14.sp,
    fontWeight: FontWeight.w400,
    height: 1.6,
  );

  static TextStyle get bodyMedium => TextStyle(
    fontFamily: sansFamily,
    fontSize: 12.sp,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  static TextStyle get caption => TextStyle(
    fontFamily: sansFamily,
    fontSize: 10.sp,
    fontWeight: FontWeight.w400,
    height: 1.4,
  );

  static TextStyle get button => TextStyle(
    fontFamily: sansFamily,
    fontSize: 13.sp,
    fontWeight: FontWeight.w500,
    height: 1.2,
  );

  static TextStyle get arabicBody => const TextStyle(
    fontFamily: 'AmiriQuran', // add the asset — see note below
    fontSize: 19,
    height: 1.9,
  );
}
