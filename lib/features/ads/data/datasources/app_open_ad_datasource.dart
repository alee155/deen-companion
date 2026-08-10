import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../../../core/utils/logger.dart';
import '../constants/ad_unit_ids.dart';

/// Talks to the Mobile Ads SDK for app open ads and nothing else. Expiry
/// tracking, lifecycle wiring, and re-preloading all live in
/// [AdsRepositoryImpl] / the app-open lifecycle manager.
class AppOpenAdDataSource {
  const AppOpenAdDataSource();

  /// Requests one app open ad. Completes with `null` (never throws) on
  /// failure.
  Future<AppOpenAd?> load() {
    debugPrint('[Ads] [AppOpen] adUnitId = ${AdUnitIds.appOpen}');
    final completer = Completer<AppOpenAd?>();

    AppOpenAd.load(
      adUnitId: AdUnitIds.appOpen,
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
