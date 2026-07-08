import 'package:flutter/material.dart';

/// Deen app palette — warm cream, gold, and espresso, replacing the earlier
/// cool emerald direction. Every screen references these constants by name,
/// never a raw hex — so updating values here propagates app-wide.
class AppColors {
  AppColors._();

  // ── Brand — was deep emerald, now warm espresso + gold ──
  static const Color emeraldInk = Color(
    0xFF3D2B1F,
  ); // primary/hero surfaces, buttons, bottom nav
  static const Color emeraldInkDark = Color(0xFF2A1D14);
  static const Color gold = Color(0xFFD9A441);
  static const Color goldLight = Color(0xFFF6E9D2);

  // Secondary warm accent — the vivid amber/orange used for the Qibla
  // needle and other high-emphasis highlights (CTAs, "live" indicators).
  static const Color amber = Color(0xFFE8823C);
  static const Color amberDeep = Color(0xFFC96A2E);

  // ── Background gradient — the warm cream-to-gold wash from the Qibla screen ──
  static const Color backgroundGradientStart = Color(0xFFFDF8F0);
  static const Color backgroundGradientEnd = Color(0xFFF3E2C8);

  // ── Neutrals — light mode ──
  static const Color parchment = Color(0xFFFAF3E7);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color borderWarm = Color(0xFFE9D8BB);
  static const Color inkText = Color(0xFF2B2420);
  static const Color textSecondary = Color(0xFF7A6F5D);
  static const Color textMuted = Color(0xFFA89A80);

  // ── Neutrals — dark mode ──
  static const Color backgroundDark = Color(0xFF1C140D);
  static const Color surfaceDark = Color(0xFF241A11);
  static const Color borderDark = Color(0xFF3A2C1D);
  static const Color textPrimaryDark = Color(0xFFF5EDE0);
  static const Color textSecondaryDark = Color(0xFFC9B9A0);

  // ── Module accents — warmed to match, still individually distinguishable ──
  static const Color quranAccent = Color(
    0xFF5C6E42,
  ); // warm olive, was cool emerald-tied
  static const Color quranAccentBg = Color(0xFFE7EBDC);

  static const Color hadithAccent = Color(0xFF7A3B2E);
  static const Color hadithAccentBg = Color(0xFFF2E2DB);

  static const Color duasAccent = Color(0xFF9C7A35);
  static const Color duasAccentBg = goldLight;

  static const Color hijriAccent = Color(
    0xFF6B5B45,
  ); // warm taupe-bronze, was cool slate
  static const Color hijriAccentBg = Color(0xFFEDE6D8);

  static const Color worshipAccent = Color(
    0xFFD9722E,
  ); // warm terracotta, was cool teal
  static const Color worshipAccentBg = Color(0xFFFBE7D3);

  static const Color toolsAccent = Color(0xFFA8632E);
  static const Color toolsAccentBg = Color(0xFFF3E4DC);

  // ── Semantic ──
  static const Color success = Color(0xFF5C6E42);
  static const Color error = Color(0xFFB0453B);
  static const Color warning = gold;
}
