import 'package:flutter/material.dart';

/// Deen app palette — emerald ink + antique gold, warm parchment neutrals.
/// Each content module (Quran, Hadith, Duas, Hijri) carries its own quiet
/// accent so the app has variety without becoming a rainbow — accents are
/// used for icon tints and small badges only, never full fills.
class AppColors {
  AppColors._();

  // ── Brand ──
  static const Color emeraldInk = Color(0xFF0F3D33);
  static const Color emeraldInkDark = Color(0xFF0B2A23);
  static const Color gold = Color(0xFFBE9B4D);
  static const Color goldLight = Color(0xFFF5EDD9);
  static const Color worshipAccent = Color(0xFF2E5F6B);
  static const Color worshipAccentBg = Color(0xFFE3EEF0);

  static const Color toolsAccent = Color(0xFFA85C3B);
  static const Color toolsAccentBg = Color(0xFFF3E4DC);
  // ── Neutrals — light mode ──
  static const Color parchment = Color(0xFFF7F3EA);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color borderWarm = Color(0xFFE8E2D3);
  static const Color inkText = Color(0xFF16241F);
  static const Color textSecondary = Color(0xFF6B6F65);
  static const Color textMuted = Color(0xFF9A968A);

  // ── Neutrals — dark mode ──
  static const Color backgroundDark = Color(0xFF0B1512);
  static const Color surfaceDark = Color(0xFF131F1A);
  static const Color borderDark = Color(0xFF23322C);
  static const Color textPrimaryDark = Color(0xFFF2EFE6);
  static const Color textSecondaryDark = Color(0xFFAAB3AC);

  // ── Module accents (icon tints + badges only) ──
  static const Color quranAccent = emeraldInk;
  static const Color quranAccentBg = Color(0xFFE1EDE9);

  static const Color hadithAccent = Color(0xFF6E2A3B);
  static const Color hadithAccentBg = Color(0xFFF1E0E3);

  static const Color duasAccent = Color(0xFF8A6D2E);
  static const Color duasAccentBg = goldLight;

  static const Color hijriAccent = Color(0xFF3A4A63);
  static const Color hijriAccentBg = Color(0xFFE4E8EE);

  // ── Semantic ──
  static const Color success = Color(0xFF3B7D5C);
  static const Color error = Color(0xFFB0453B);
  static const Color warning = gold;
}
