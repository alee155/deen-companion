import '../entities/banner_ad_handle.dart';

/// Invoked once an interstitial flow is finished — whether it actually
/// showed an ad, failed to show one, or there was nothing to show at all.
/// Callers use this single hook to resume whatever they were about to do
/// (almost always a navigation), so an ad can never leave the user stuck.
typedef AdFlowComplete = void Function();

/// Single point of contact between the rest of the app and the Google
/// Mobile Ads SDK. Presentation-layer providers and widgets talk to this
/// interface only — the concrete SDK types (`BannerAd`, `InterstitialAd`,
/// `AppOpenAd`, ...) stay inside the data layer's datasources and the
/// implementation of this repository.
abstract class AdsRepository {
  /// Initializes the Mobile Ads SDK. Safe to call once at startup; must
  /// complete (or be skipped) before any ad is requested.
  Future<void> initialize();

  // ---------------------------------------------------------------------
  // Banner
  // ---------------------------------------------------------------------

  /// Loads one banner ad sized for [width] (an adaptive anchored banner).
  /// Returns `null` on failure — callers should collapse their banner slot
  /// rather than show a broken placeholder. Every call loads an
  /// independent ad; ownership (and disposal) belongs to the caller.
  Future<BannerAdHandle?> loadBanner({required double width});

  // ---------------------------------------------------------------------
  // Interstitial
  // ---------------------------------------------------------------------

  /// True once an interstitial has finished loading and hasn't been shown
  /// (or discarded after a failed show) yet.
  bool get isInterstitialReady;

  /// Warms up the next interstitial in the background. Safe to call
  /// repeatedly — a load already in flight, or an ad already sitting
  /// ready, is left alone rather than duplicated.
  Future<void> preloadInterstitial();

  /// Shows the currently loaded interstitial, if any, and calls
  /// [onComplete] exactly once — after the user dismisses it, if it fails
  /// to show, or immediately if none is ready. Never makes the caller wait
  /// on a network load; if nothing is ready right now, [onComplete] fires
  /// straight away and a fresh ad is queued for next time.
  void showInterstitial({required AdFlowComplete onComplete});

  // ---------------------------------------------------------------------
  // App Open
  // ---------------------------------------------------------------------

  /// True while an interstitial or app open ad is currently on screen.
  /// Used to stop the two ad types from ever overlapping or firing back to
  /// back off the lifecycle transitions a full-screen ad itself causes.
  bool get isDisplayingFullScreenAd;

  /// True once an app open ad has loaded and hasn't expired (Google
  /// recommends discarding app open ads after roughly 4 hours).
  bool get isAppOpenAdReady;

  /// Warms up an app open ad for the next cold start / resume. Safe to
  /// call repeatedly for the same reasons as [preloadInterstitial].
  Future<void> preloadAppOpenAd();

  /// Shows the loaded app open ad if one is ready and nothing else is
  /// currently on screen. Returns `true` if it actually showed. Never
  /// waits on a load — if nothing is ready, returns `false` immediately.
  Future<bool> showAppOpenAdIfAvailable();

  /// Releases any ad currently held in memory (interstitial and app open).
  /// Call once, from the composition root, when the repository itself is
  /// being torn down — not per screen.
  void dispose();
}
