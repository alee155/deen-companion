import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../../../core/utils/logger.dart';
import '../constants/ad_unit_ids.dart';

/// Talks to the Mobile Ads SDK for interstitial ads and nothing else.
/// Showing, dismissal handling, and re-preloading all live in
/// [AdsRepositoryImpl] — this class is purely "ask the SDK for one ad".
class InterstitialAdDataSource {
  const InterstitialAdDataSource();

  /// Requests one interstitial. Completes with `null` (never throws) on
  /// failure, so a failed load is just "nothing to show", not a crash.
  Future<InterstitialAd?> load() {
    debugPrint('[Ads] [Interstitial] adUnitId = ${AdUnitIds.interstitial}');
    final completer = Completer<InterstitialAd?>();

    InterstitialAd.load(
      adUnitId: AdUnitIds.interstitial,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          debugPrint('[Ads] [Interstitial] onAdLoaded ✅');
          if (!completer.isCompleted) completer.complete(ad);
        },
        onAdFailedToLoad: (error) {
          debugPrint(
            '[Ads] [Interstitial] onAdFailedToLoad ❌ code=${error.code} '
            'domain=${error.domain} message=${error.message}',
          );
          AppLogger.e('Interstitial ad failed to load: $error');
          if (!completer.isCompleted) completer.complete(null);
        },
      ),
    );

    debugPrint('[Ads] [Interstitial] calling InterstitialAd.load()…');
    return completer.future;
  }
}
