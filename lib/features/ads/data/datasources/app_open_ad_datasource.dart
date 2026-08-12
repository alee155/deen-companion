import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../../../core/utils/logger.dart';

/// Talks to the Mobile Ads SDK for app open ads and nothing else. Expiry
/// tracking, lifecycle wiring, and re-preloading all live in
/// [AdsRepositoryImpl] / the app-open lifecycle manager; *which* ad unit
/// ID to use lives in `AdUnitResolver`.
class AppOpenAdDataSource {
  const AppOpenAdDataSource();

  /// Requests one app open ad using [adUnitId] (already resolved to
  /// real/test by the caller). Completes with `null` (never throws) on
  /// failure.
  Future<AppOpenAd?> load({required String adUnitId}) {
    debugPrint('[Ads] [AppOpen] adUnitId = $adUnitId');
    final completer = Completer<AppOpenAd?>();

    AppOpenAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) {
          debugPrint('[Ads] [AppOpen] onAdLoaded ✅');
          if (!completer.isCompleted) completer.complete(ad);
        },
        onAdFailedToLoad: (error) {
          debugPrint(
            '[Ads] [AppOpen] onAdFailedToLoad ❌ code=${error.code} '
            'domain=${error.domain} message=${error.message}',
          );
          AppLogger.e('App open ad failed to load: $error');
          if (!completer.isCompleted) completer.complete(null);
        },
      ),
    );

    debugPrint('[Ads] [AppOpen] calling AppOpenAd.load()…');
    return completer.future;
  }
}
