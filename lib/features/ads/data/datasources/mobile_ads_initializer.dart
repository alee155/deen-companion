import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../../../core/config/flavor_config.dart';
import '../../../../core/utils/logger.dart';
import '../constants/ad_unit_ids.dart';
import '../constants/ads_config.dart';

/// Owns the one-time setup calls the Mobile Ads SDK needs before any ad
/// (banner, interstitial, or app open) can be requested.
class MobileAdsInitializer {
  const MobileAdsInitializer();

  Future<void> initialize() async {
    debugPrint('[Ads] ── Config ──────────────────────────────────');
    debugPrint('[Ads] AdsConfig.adsEnabled = ${AdsConfig.adsEnabled}');
    debugPrint('[Ads] AdsConfig.useTestAds = ${AdsConfig.useTestAds}');
    debugPrint('[Ads] Banner ad unit id       = ${AdUnitIds.banner}');
    debugPrint('[Ads] Interstitial ad unit id = ${AdUnitIds.interstitial}');
    debugPrint('[Ads] App Open ad unit id     = ${AdUnitIds.appOpen}');
    debugPrint('[Ads] ─────────────────────────────────────────────');

    // Deen Companion is general-audience content (not child-directed) —
    // this keeps AdMob's request-level content controls aligned with what
    // Section 7 of the Privacy Policy and Section 2 of the Terms already
    // state, and caps ad content at "General audiences" so nothing served
    // clashes with the tone of the rest of the app.
    await MobileAds.instance.updateRequestConfiguration(
      RequestConfiguration(
        tagForChildDirectedTreatment: TagForChildDirectedTreatment.no,
        tagForUnderAgeOfConsent: TagForUnderAgeOfConsent.no,
        maxAdContentRating: MaxAdContentRating.g,
      ),
    );

    try {
      final status = await MobileAds.instance.initialize();
      final adapterStatuses = status.adapterStatuses;
      debugPrint(
        '[Ads] MobileAds.instance.initialize() completed — '
        '${adapterStatuses.length} adapter(s) reported',
      );
      adapterStatuses.forEach((adapter, adapterStatus) {
        debugPrint(
          '[Ads]   adapter=$adapter state=${adapterStatus.state} '
          'description="${adapterStatus.description}" '
          'latency=${adapterStatus.latency}ms',
        );
      });
    } catch (error, stackTrace) {
      // Ads are a monetization layer, not a core feature — a failed SDK
      // initialization (e.g. no Google Play Services on a device) must
      // never stop the rest of the app from starting. Every subsequent ad
      // load will simply keep failing gracefully.
      debugPrint('[Ads] MobileAds.instance.initialize() threw: $error');
      AppLogger.e('Mobile Ads SDK initialization failed', error, stackTrace);
    }
  }

  /// Registers this device as a test device so real ad units on a
  /// developer's own phone still return clearly-marked test creatives
  /// instead of live ads. No-op in prod builds. Call once, after
  /// [initialize], with the device ID(s) printed to the console the first
  /// time an ad request is made from an unregistered device.
  void registerTestDevices(List<String> deviceIds) {
    if (FlavorConfig.isProd || deviceIds.isEmpty) return;
    debugPrint('[Ads] Registering test device IDs: $deviceIds');
    MobileAds.instance.updateRequestConfiguration(
      RequestConfiguration(testDeviceIds: deviceIds),
    );
  }
}
