import 'package:flutter/animation.dart';
import 'package:flutter/widgets.dart';

/// How much motion the app plays. [reduced] is derived from the OS
/// "remove animations" setting and always wins; the other levels scale
/// travel distances so the whole app can be dialled up or down in one place.
enum MotionLevel {
  reduced(0),
  subtle(0.6),
  standard(1),
  expressive(1.4);

  const MotionLevel(this.distanceScale);

  /// Multiplier applied to entrance travel distances.
  final double distanceScale;
}

/// The app's motion design language: durations, curves, stagger and
/// distances. Nothing outside `core/motion` should invent its own timings.
///
/// Rules of thumb:
///  * taps/toggles: [instant]–[fast]
///  * components appearing or changing: [normal]
///  * screen-level moves: [page]; hero/celebration moments: [slow]
///  * everything is one-shot — no looping animation unless it conveys live
///    state (e.g. the audio disc while playing).
class AppMotion {
  AppMotion._();

  // ── Durations ──────────────────────────────────────────────────────────
  /// Press-down feedback.
  static const Duration instant = Duration(milliseconds: 90);
  static const Duration fast = Duration(milliseconds: 180);
  static const Duration normal = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 420);

  /// Screen push/pop.
  static const Duration page = Duration(milliseconds: 320);
  static const Duration pageReverse = Duration(milliseconds: 260);

  /// Press-release / spring-back.
  static const Duration release = Duration(milliseconds: 220);

  /// Numbers/progress catching up to a new value.
  static const Duration value = Duration(milliseconds: 700);

  // ── Curves ─────────────────────────────────────────────────────────────
  /// Default for anything entering or settling.
  static const Curve entrance = Curves.easeOutCubic;
  static const Curve exit = Curves.easeInCubic;

  /// Slightly more decisive than [entrance]; used for pages and sheets.
  static const Curve emphasized = Cubic(0.2, 0.0, 0.0, 1.0);

  /// One gentle overshoot for celebratory pops (success check, streak).
  static const Curve pop = Curves.easeOutBack;
  static const Curve standard = Curves.easeInOutCubic;

  // ── Stagger ────────────────────────────────────────────────────────────
  static const int staggerStepMs = 28;

  /// Items past this index appear together (with no delay) so item #40
  /// never waits behind a long cascade.
  static const int staggerCap = 10;

  static Duration stagger(int index, {int maxIndex = staggerCap}) {
    final i = index > maxIndex ? maxIndex : index;
    return Duration(milliseconds: staggerStepMs * i);
  }

  // ── Distances (fractions of the child's own size) ─────────────────────
  static const double riseSmall = 0.06;
  static const double rise = 0.10;

  // ── Press feedback ─────────────────────────────────────────────────────
  static const double pressScale = 0.97;
  static const double pressScaleSmall = 0.90; // icon buttons / chips

  // ── Overlay presentation ───────────────────────────────────────────────
  static const AnimationStyle sheetStyle = AnimationStyle(
    duration: Duration(milliseconds: 320),
    reverseDuration: Duration(milliseconds: 220),
    curve: emphasized,
    reverseCurve: Curves.easeInCubic,
  );

  static const AnimationStyle dialogStyle = AnimationStyle(
    duration: Duration(milliseconds: 240),
    reverseDuration: Duration(milliseconds: 160),
    curve: emphasized,
    reverseCurve: Curves.easeIn,
  );
}
