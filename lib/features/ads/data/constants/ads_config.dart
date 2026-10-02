/// Local, hand-flipped switches for the whole Ads feature.
///
/// Per-ad-type real/test/disabled decisions are resolved centrally by
/// `AdUnitResolver` (`data/services/ad_unit_resolver.dart`) from the flags
/// below.
class AdsConfig {
  AdsConfig._();

  /// Master on/off switch for ads.
  ///
  /// `false` — the SDK is never initialized, no banner/interstitial/app
  /// open ad is ever requested, loaded, or shown. Banner slots collapse to
  /// nothing, interstitials let navigation through untouched, app open
  /// never fires.
  static const bool adsEnabled = true;

  /// Per-format switches. Each is only consulted when [adsEnabled] is
  /// `true`:
  ///   `true`  → real production ad unit in release builds, Google's test
  ///             ad unit in debug builds.
  ///   `false` → that ad format is never shown.
  static const bool bannerEnabled = true;
  static const bool interstitialEnabled = true;
  static const bool appOpenEnabled = true;
}
