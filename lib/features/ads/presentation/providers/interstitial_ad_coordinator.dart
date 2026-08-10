import 'package:flutter/foundation.dart' show VoidCallback, debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/ad_placement_key.dart';
import 'ads_providers.dart';
import 'interstitial_click_counter_provider.dart';

/// Central entry point for every interstitial placement in the app.
///
/// A screen that wants "show an interstitial on some clicks, then do the
/// thing the user tapped for" calls [showThenRun] instead of managing its
/// own counter, its own loaded-ad check, or its own ad instance. This is
/// the piece that makes the odd/even rule reusable rather than
/// reimplemented per screen.
class InterstitialAdCoordinator {
  final Ref _ref;
  const InterstitialAdCoordinator(this._ref);

  /// Runs [action] — normally a navigation — optionally showing an
  /// interstitial first.
  ///
  /// 1. Registers a click against [placement]'s counter and checks the
  ///    shared odd/even rule.
  /// 2. If this click isn't due for an ad, or no ad is currently loaded,
  ///    [action] runs immediately — a user should never wait on an ad
  ///    that was never going to appear.
  /// 3. If this click is due and an ad is ready, the ad shows first and
  ///    [action] runs once it's dismissed (or fails to show), so
  ///    navigation always ends up happening exactly once, never blocked.
  void showThenRun({
    required AdPlacementKey placement,
    required VoidCallback action,
  }) {
    final isDue = _ref
        .read(interstitialClickCounterProvider(placement).notifier)
        .registerClickAndShouldShow();

    final clickCount = _ref.read(interstitialClickCounterProvider(placement));
    debugPrint(
      '[Ads] [Interstitial coordinator] placement=$placement '
      'clickCount=$clickCount isDue=$isDue',
    );

    if (!isDue) {
      action();
      return;
    }

    final repository = _ref.read(adsRepositoryProvider);
    if (!repository.isInterstitialReady) {
      debugPrint(
        '[Ads] [Interstitial coordinator] due, but no ad ready — '
        'continuing without one',
      );
      action();
      return;
    }

    debugPrint('[Ads] [Interstitial coordinator] due and ready — showing');
    repository.showInterstitial(onComplete: action);
  }
}

final interstitialAdCoordinatorProvider = Provider<InterstitialAdCoordinator>(
  (ref) => InterstitialAdCoordinator(ref),
);
