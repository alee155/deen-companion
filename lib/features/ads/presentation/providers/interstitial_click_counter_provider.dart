import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/ad_placement_key.dart';

/// Per-placement click counter behind the shared 1st/3rd/5th… interstitial
/// rule. This is the one place that rule is implemented — every screen
/// reuses it through [InterstitialAdCoordinator] instead of hand-rolling
/// its own counter.
///
/// Deliberately in-memory only (resets on app restart, not persisted to
/// Hive): the frequency rule exists to avoid showing back-to-back
/// interstitials within a single browsing session, not to cap lifetime
/// impressions — AdMob's own ad unit frequency capping settings already
/// cover the latter, and persisting a counter that gets written on every
/// tap would be a lot of extra local storage I/O for no real benefit.
class InterstitialClickCounterNotifier
    extends FamilyNotifier<int, AdPlacementKey> {
  @override
  int build(AdPlacementKey arg) => 0;

  /// Registers a click for this placement and reports whether *this*
  /// click is due for an interstitial: the 1st, 3rd, 5th… click, and so
  /// on. Every placement starts its own count at zero, independently.
  bool registerClickAndShouldShow() {
    state = state + 1;
    return state.isOdd;
  }
}

final interstitialClickCounterProvider =
    NotifierProvider.family<
      InterstitialClickCounterNotifier,
      int,
      AdPlacementKey
    >(InterstitialClickCounterNotifier.new);
