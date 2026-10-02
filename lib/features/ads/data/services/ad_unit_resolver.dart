import 'dart:io';

import 'package:flutter/foundation.dart';

import '../constants/ad_mob_ids.dart';
import '../constants/ads_config.dart';

/// What an ad-unit resolution decided to do.
enum AdAvailability {
  /// This ad type is enabled and this is a release build — use the real
  /// AdMob ad unit.
  real,

  /// This ad type is enabled and this is a debug build — use Google's
  /// public test ad unit so development/QA sees ads without generating
  /// real ad traffic.
  test,

  /// This ad type is switched off in [AdsConfig] — don't show it at all.
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

/// Single centralized place that decides, per ad format, whether to serve
/// real ads, test ads, or nothing at all. Every ad datasource/repository
/// call goes through this instead of reading [AdsConfig] or picking an ad
/// unit ID itself — that's what makes the real/test/disabled rule
/// "reusable" rather than reimplemented per ad type.
///
/// The rule, applied identically to Banner, Interstitial, and App Open:
///   • format switched off in [AdsConfig]  → disabled (no ad)
///   • format enabled, debug build         → Google's test ad unit
///   • format enabled, release build, iOS  → disabled ([AdMobIds] only
///                                           holds Android ad units)
///   • format enabled, release, no unit ID → disabled (IDs are injected via
///                                           --dart-define, never committed)
///   • format enabled, release build       → real ad unit
class AdUnitResolver {
  const AdUnitResolver();

  ResolvedAdUnit banner() => _resolve(
    label: 'Banner',
    enabled: AdsConfig.bannerEnabled,
    prodAdUnitId: AdMobIds.prodBanner,
    testAdUnitId: Platform.isIOS ? AdMobIds.iosTestBanner : AdMobIds.testBanner,
  );

  ResolvedAdUnit interstitial() => _resolve(
    label: 'Interstitial',
    enabled: AdsConfig.interstitialEnabled,
    prodAdUnitId: AdMobIds.prodInterstitial,
    testAdUnitId: Platform.isIOS
        ? AdMobIds.iosTestInterstitial
        : AdMobIds.testInterstitial,
  );

  ResolvedAdUnit appOpen() => _resolve(
    label: 'AppOpen',
    enabled: AdsConfig.appOpenEnabled,
    prodAdUnitId: AdMobIds.prodAppOpen,
    testAdUnitId: Platform.isIOS
        ? AdMobIds.iosTestAppOpen
        : AdMobIds.testAppOpen,
  );

  ResolvedAdUnit _resolve({
    required String label,
    required bool enabled,
    required String prodAdUnitId,
    required String testAdUnitId,
  }) {
    if (!enabled) {
      debugPrint('[AdUnitResolver] $label: disabled in AdsConfig');
      return const ResolvedAdUnit.disabled();
    }

    if (kDebugMode) {
      debugPrint('[AdUnitResolver] $label: debug build → test ad unit');
      return ResolvedAdUnit.test(testAdUnitId);
    }

    if (Platform.isIOS) {
      debugPrint('[AdUnitResolver] $label: no iOS ad units yet → disabled');
      return const ResolvedAdUnit.disabled();
    }

    if (prodAdUnitId.isEmpty) {
      debugPrint('[AdUnitResolver] $label: no production ad unit configured');
      return const ResolvedAdUnit.disabled();
    }

    debugPrint('[AdUnitResolver] $label: release build → real ad unit');
    return ResolvedAdUnit.real(prodAdUnitId);
  }
}
