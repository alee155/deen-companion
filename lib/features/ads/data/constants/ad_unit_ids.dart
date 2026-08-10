import 'dart:io';

import 'ads_config.dart';

/// Resolves which AdMob ad unit ID to use for each ad type/platform.
///
/// Which set (test vs. real) is used is controlled by a single flag —
/// `AdsConfig.useTestAds` — not by build flavor. That's deliberate: you
/// may well want to see real ads while running a dev build against
/// staging content, or double-check test ads still work in a prod build
/// before a release. The two concerns (dev/prod build, test/real ads)
/// are independent, so they get independent switches.
///
/// ── TODO before release ──────────────────────────────────────────────
/// Once the real AdMob App ID + ad unit IDs are issued:
///   1. Replace the `_prodAndroid*` / `_prodIOS*` values below.
///   2. Replace the AdMob Application ID in
///      android/app/src/main/AndroidManifest.xml and
///      ios/Runner/Info.plist (GADApplicationIdentifier).
///   3. Set `AdsConfig.useTestAds` to `false`.
///   4. Nothing else in the app needs to change — every call site reads
///      through this class, never a literal ad unit ID string.
class AdUnitIds {
  AdUnitIds._();

  // Google's public test IDs — safe to ship, always available, always
  // fill with "Test Ad" creatives. Same values Google publishes in its
  // own quick-start docs.
  static const _testAndroidBanner = 'ca-app-pub-3940256099942544/9214589741';
  static const _testAndroidInterstitial =
      'ca-app-pub-3940256099942544/1033173712';
  static const _testAndroidAppOpen = 'ca-app-pub-3940256099942544/9257395921';

  static const _testIOSBanner = 'ca-app-pub-3940256099942544/2934735716';
  static const _testIOSInterstitial = 'ca-app-pub-3940256099942544/4411468910';
  static const _testIOSAppOpen = 'ca-app-pub-3940256099942544/5575463023';

  // ── Fill these in once AdMob issues the real ad units ────────────────
  static const _prodAndroidBanner = _testAndroidBanner;
  static const _prodAndroidInterstitial = _testAndroidInterstitial;
  static const _prodAndroidAppOpen = _testAndroidAppOpen;

  static const _prodIOSBanner = _testIOSBanner;
  static const _prodIOSInterstitial = _testIOSInterstitial;
  static const _prodIOSAppOpen = _testIOSAppOpen;

  static bool get _useProdIds => !AdsConfig.useTestAds;

  static String get banner {
    if (Platform.isIOS) {
      return _useProdIds ? _prodIOSBanner : _testIOSBanner;
    }
    return _useProdIds ? _prodAndroidBanner : _testAndroidBanner;
  }

  static String get interstitial {
    if (Platform.isIOS) {
      return _useProdIds ? _prodIOSInterstitial : _testIOSInterstitial;
    }
    return _useProdIds ? _prodAndroidInterstitial : _testAndroidInterstitial;
  }

  static String get appOpen {
    if (Platform.isIOS) {
      return _useProdIds ? _prodIOSAppOpen : _testIOSAppOpen;
    }
    return _useProdIds ? _prodAndroidAppOpen : _testAndroidAppOpen;
  }
}
