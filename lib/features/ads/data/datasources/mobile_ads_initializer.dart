import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../../../core/config/flavor_config.dart';
import '../../../../core/utils/logger.dart';

class MobileAdsInitializer {
  const MobileAdsInitializer();

  // Static, not instance-level: bootstrap.dart and AdsRepositoryImpl each
  // hold their own MobileAdsInitializer() (it's a Provider, effectively a
  // singleton, but this guard is cheap insurance either way) — a static
  // Completer guarantees MobileAds.instance.initialize() is only ever
  // actually fired once per process, no matter how many call sites ask
  // for it or in what order.
  static Completer<void>? _initCompleter;

  Future<void> initialize() {
    final existing = _initCompleter;
    if (existing != null) return existing.future;

    final completer = Completer<void>();
    _initCompleter = completer;
    _initInternal().then((_) => completer.complete());
    return completer.future;
  }

  Future<void> _initInternal() async {
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
      debugPrint('[Ads] MobileAds.instance.initialize() threw: $error');
      AppLogger.e('Mobile Ads SDK initialization failed', error, stackTrace);
    }
  }

  void registerTestDevices(List<String> deviceIds) {
    if (FlavorConfig.isProd || deviceIds.isEmpty) return;
    debugPrint('[Ads] Registering test device IDs: $deviceIds');
    MobileAds.instance.updateRequestConfiguration(
      RequestConfiguration(testDeviceIds: deviceIds),
    );
  }
}
