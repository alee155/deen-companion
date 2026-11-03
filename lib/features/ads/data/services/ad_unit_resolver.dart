import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../domain/entities/remote_ads_config.dart';
import '../constants/ad_mob_ids.dart';

/// What an ad-unit resolution decided to do.
enum AdAvailability {
  /// Switched on by the ads service in a release build: use the real unit.
  real,

  /// Switched on in a debug build: use Google's public test unit, so
  /// development never generates real ad traffic.
  test,

  /// Switched off, or no unit id: show nothing.
  disabled,
}

/// The outcome of resolving one ad type: what to do, and — when there's
/// something to load — which ad unit ID to load it with.
class ResolvedAdUnit {
  final AdAvailability availability;
  final String? adUnitId;

  const ResolvedAdUnit._(this.availability, this.adUnitId);

  const ResolvedAdUnit.real(String adUnitId)
    : this._(AdAvailability.real, adUnitId);
  const ResolvedAdUnit.test(String adUnitId)
    : this._(AdAvailability.test, adUnitId);
  const ResolvedAdUnit.disabled() : this._(AdAvailability.disabled, null);

  bool get shouldLoad => adUnitId != null;
}

/// The single place that decides, per ad type, whether to serve a real ad, a
/// test ad or nothing. It only reads the ads service's answer: the server has
/// already combined every switch, so no extra logic is added here.
///
///   • not [AdSlotConfig.usable] (off, or no unit id) → disabled
///   • usable, debug build                            → Google's test unit
///   • usable, release build                          → the server's unit id
///
/// Unit ids are never hardcoded for release; they always come from the
/// config.
class AdUnitResolver {
  final RemoteAdsConfig Function() _config;

  const AdUnitResolver(this._config);

  ResolvedAdUnit banner() => _resolve(
    'Banner',
    _config().banner,
    Platform.isIOS ? AdMobIds.iosTestBanner : AdMobIds.testBanner,
  );

  ResolvedAdUnit interstitial() => _resolve(
    'Interstitial',
    _config().interstitial,
    Platform.isIOS ? AdMobIds.iosTestInterstitial : AdMobIds.testInterstitial,
  );

  ResolvedAdUnit appOpen() => _resolve(
    'AppOpen',
    _config().appOpen,
    Platform.isIOS ? AdMobIds.iosTestAppOpen : AdMobIds.testAppOpen,
  );

  ResolvedAdUnit _resolve(String label, AdSlotConfig slot, String testUnit) {
    final config = _config();
    if (!config.adsEnabled || !slot.usable) {
      debugPrint('[AdUnitResolver] $label: off in the ads config');
      return const ResolvedAdUnit.disabled();
    }
    if (kDebugMode) {
      debugPrint('[AdUnitResolver] $label: debug build → test ad unit');
      return ResolvedAdUnit.test(testUnit);
    }
    debugPrint('[AdUnitResolver] $label: release build → server ad unit');
    return ResolvedAdUnit.real(slot.unitId!);
  }
}
