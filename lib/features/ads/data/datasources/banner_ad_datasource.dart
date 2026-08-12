import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../../../core/utils/logger.dart';
import '../../domain/entities/banner_ad_handle.dart';

/// Talks to the Mobile Ads SDK for banner ads and nothing else — no app
/// state, no counters, no lifecycle handling, and (as of the Remote
/// Config rework) no opinion on *which* ad unit ID to use either — that
/// decision belongs to `AdUnitResolver` and is handed in by
/// [AdsRepositoryImpl]. This class only knows how to ask the SDK for one
/// banner and turn its load/fail callbacks into a `Future`.
class BannerAdDataSource {
  const BannerAdDataSource();

  /// Requests an adaptive anchored banner sized for [width], using
  /// [adUnitId] (already resolved to real/test by the caller). Completes
  /// with `null` (never throws) if sizing or loading fails, so callers
  /// can treat "no ad" as a normal outcome rather than an error path.
  Future<BannerAdHandle?> load({
    required double width,
    required String adUnitId,
  }) async {
    debugPrint('[Ads] [Banner] adUnitId = $adUnitId');

    final size = await AdSize.getAnchoredAdaptiveBannerAdSize(
      Orientation.portrait,
      width.truncate(),
    );

    if (size == null) {
      debugPrint('[Ads] [Banner] getAnchoredAdaptiveBannerAdSize returned null for width=$width');
      AppLogger.e('Banner ad: could not resolve an adaptive size');
      return null;
    }
    debugPrint('[Ads] [Banner] resolved adaptive size: ${size.width}x${size.height}');

    final completer = Completer<BannerAdHandle?>();

    final bannerAd = BannerAd(
      adUnitId: adUnitId,
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          debugPrint('[Ads] [Banner] onAdLoaded ✅');
          if (!completer.isCompleted) {
            completer.complete(BannerAdHandle(ad: ad as BannerAd, size: size));
          }
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint(
            '[Ads] [Banner] onAdFailedToLoad ❌ code=${error.code} '
            'domain=${error.domain} message=${error.message}',
          );
          AppLogger.e('Banner ad failed to load: $error');
          ad.dispose();
          if (!completer.isCompleted) completer.complete(null);
        },
        onAdOpened: (ad) => debugPrint('[Ads] [Banner] onAdOpened'),
        onAdClosed: (ad) => debugPrint('[Ads] [Banner] onAdClosed'),
        onAdImpression: (ad) => debugPrint('[Ads] [Banner] onAdImpression'),
        onAdClicked: (ad) => debugPrint('[Ads] [Banner] onAdClicked'),
      ),
    );

    debugPrint('[Ads] [Banner] calling bannerAd.load()…');
    bannerAd.load();
    return completer.future;
  }
}
