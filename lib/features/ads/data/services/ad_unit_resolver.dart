import 'package:flutter/foundation.dart';

import '../../../../core/remote_config/remote_config_service.dart';
import '../constants/ad_mob_ids.dart';
import '../constants/remote_config_keys.dart';

/// What an ad-unit resolution decided to do.
enum AdAvailability {
  /// Remote Config says this ad type is live — use the real AdMob ad
  /// unit.
  real,

  /// Remote Config says this ad type is off, and this is a debug build —
  /// fall back to Google's public test ad unit so development/QA still
  /// sees ads.
  test,

  /// Remote Config says this ad type is off, and this is a release
  /// build — don't show this ad type at all. A debug build never
  /// resolves to this: the whole point of `test` is that debug always has
  /// *something* to show while iterating.
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
/// call goes through this instead of reading Remote Config or picking an
/// ad unit ID itself — that's what makes the real/test/disabled rule
/// "reusable" rather than reimplemented per ad type.
///
/// The rule, applied identically to Banner, Interstitial, and App Open:
///   • Remote Config flag `true`                    → real ad unit
///   • Remote Config flag `false`, debug build       → Google's test ad unit
///   • Remote Config flag `false`, release build     → disabled (no ad)
class AdUnitResolver {
  final RemoteConfigService _remoteConfig;
  const AdUnitResolver(this._remoteConfig);

  ResolvedAdUnit banner() => _resolve(
    label: 'Banner',
    remoteConfigKey: RemoteConfigKeys.banner,
    prodAdUnitId: AdMobIds.prodBanner,
    testAdUnitId: AdMobIds.testBanner,
  );

  ResolvedAdUnit interstitial() => _resolve(
    label: 'Interstitial',
    remoteConfigKey: RemoteConfigKeys.interstitial,
    prodAdUnitId: AdMobIds.prodInterstitial,
    testAdUnitId: AdMobIds.testInterstitial,
  );

  ResolvedAdUnit appOpen() => _resolve(
    label: 'AppOpen',
    remoteConfigKey: RemoteConfigKeys.appOpen,
    prodAdUnitId: AdMobIds.prodAppOpen,
    testAdUnitId: AdMobIds.testAppOpen,
  );

  ResolvedAdUnit _resolve({
    required String label,
    required String remoteConfigKey,
    required String prodAdUnitId,
    required String testAdUnitId,
  }) {
    // false is the safe default here on purpose — see
    // FirebaseRemoteConfigService.setDefaults, which sets the same
    // default locally. If Remote Config hasn't fetched yet (or fails
    // entirely), this resolves exactly the same way "off" does: test ads
    // in debug, nothing in release. Never real ads by accident.
    final remoteEnabled = _remoteConfig.getBool(
      remoteConfigKey,
      defaultValue: false,
    );

    if (remoteEnabled) {
      debugPrint('[AdUnitResolver] $label: Remote Config = true → real ad unit');
      return ResolvedAdUnit.real(prodAdUnitId);
    }

    if (kDebugMode) {
      debugPrint(
        '[AdUnitResolver] $label: Remote Config = false, debug build '
        '→ test ad unit',
      );
      return ResolvedAdUnit.test(testAdUnitId);
    }

    debugPrint(
      '[AdUnitResolver] $label: Remote Config = false, release build '
      '→ disabled',
    );
    return const ResolvedAdUnit.disabled();
  }
}
