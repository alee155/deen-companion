import 'package:flutter/services.dart';

/// Single place for haptic feedback so intensity stays consistent.
/// All calls are fire-and-forget and safe on platforms without a motor.
class AppHaptics {
  AppHaptics._();

  /// Light tick: selecting a tab, chip, option or toggle.
  static void selection() => HapticFeedback.selectionClick();

  /// Confirming a primary action (button press, counter increment).
  static void tap() => HapticFeedback.lightImpact();

  /// Completing something meaningful (dhikr complete, saved, streak).
  static void success() => HapticFeedback.mediumImpact();

  /// Errors or destructive confirmations.
  static void error() => HapticFeedback.heavyImpact();
}
