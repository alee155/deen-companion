import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Centralized motion constants so animations feel consistent across the
/// whole app instead of every screen inventing its own timings.
///
/// Kept deliberately restrained: short durations, no looping/repeating
/// effects, and a stagger cap so long lists don't end up with a multi-second
/// cascade. Every animation here runs once on build and settles — nothing
/// keeps the frame pipeline busy after it finishes.
class AppMotion {
  AppMotion._();

  static const Duration fast = Duration(milliseconds: 180);
  static const Duration normal = Duration(milliseconds: 320);
  static const Duration slow = Duration(milliseconds: 420);

  static const Curve entrance = Curves.easeOutCubic;
  static const Curve exit = Curves.easeInCubic;

  /// Per-item stagger delay for lists/grids, capped so item #40 doesn't wait
  /// almost a full second to appear.
  static Duration stagger(int index, {int maxIndex = 12}) {
    final effectiveIndex = index > maxIndex ? maxIndex : index;
    return Duration(milliseconds: 24 * effectiveIndex);
  }
}

/// Reusable entrance-animation extensions built on top of flutter_animate.
extension AppEntranceAnimation on Widget {
  /// Standard "card/section appears" animation: fade in + gentle rise.
  /// Use for hero cards, section cards, and other standalone content
  /// blocks that appear once when a screen loads.
  Widget appear({Duration delay = Duration.zero}) {
    return animate(delay: delay)
        .fadeIn(duration: AppMotion.normal, curve: AppMotion.entrance)
        .slideY(
          begin: 0.08,
          end: 0,
          duration: AppMotion.normal,
          curve: AppMotion.entrance,
        );
  }

  /// Staggered list/grid item entrance. Pass the item's index so items
  /// cascade in slightly after one another instead of popping in at once.
  Widget appearStaggered(int index, {int maxIndex = 12}) {
    return animate(delay: AppMotion.stagger(index, maxIndex: maxIndex))
        .fadeIn(duration: AppMotion.fast, curve: AppMotion.entrance)
        .slideY(
          begin: 0.10,
          end: 0,
          duration: AppMotion.fast,
          curve: AppMotion.entrance,
        );
  }

  /// Subtle scale-in, useful for icon tiles / quick-access grids where a
  /// vertical slide would look odd in a dense grid.
  Widget popIn({Duration delay = Duration.zero}) {
    return animate(delay: delay)
        .fadeIn(duration: AppMotion.fast, curve: AppMotion.entrance)
        .scaleXY(
          begin: 0.90,
          end: 1,
          duration: AppMotion.fast,
          curve: AppMotion.entrance,
        );
  }
}
