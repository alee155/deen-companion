/// The one remaining hand-flipped switch for the whole Ads feature.
///
/// Per-ad-type real/test/disabled decisions are no longer made here — that
/// logic moved to Firebase Remote Config, resolved centrally by
/// `AdUnitResolver` (`data/services/ad_unit_resolver.dart`). This flag is
/// the one thing that stays a local, no-network kill switch: useful if
/// Remote Config itself is unreachable, or you just want a guaranteed way
/// to build/demo/test the app with zero ad traffic regardless of what
/// Firebase says.
class AdsConfig {
  AdsConfig._();

  /// Master on/off switch for ads.
  ///
  /// `false` — the SDK is never initialized, no banner/interstitial/app
  /// open ad is ever requested, loaded, or shown, and Remote Config is
  /// never even consulted. Banner slots collapse to nothing, interstitials
  /// let navigation through untouched, app open never fires.
  static const bool adsEnabled = true;
}
