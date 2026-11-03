/// Google's public test ad units, used by debug builds only. Release builds
/// use the unit ids the ads service sends (see `AdUnitResolver`); nothing
/// here is a real id, and none is ever hardcoded for release.
///
/// The AdMob **application** id is different: the SDK needs it at launch, so
/// it lives in the platform files (`AndroidManifest.xml` via
/// `android/admob.properties`, and `GADApplicationIdentifier` in
/// `ios/Runner/Info.plist`).
class AdMobIds {
  AdMobIds._();

  // https://developers.google.com/admob/flutter/test-ads
  static const String testBanner = 'ca-app-pub-3940256099942544/9214589741';
  static const String testInterstitial =
      'ca-app-pub-3940256099942544/1033173712';
  static const String testAppOpen = 'ca-app-pub-3940256099942544/9257395921';

  static const String iosTestBanner = 'ca-app-pub-3940256099942544/2934735716';
  static const String iosTestInterstitial =
      'ca-app-pub-3940256099942544/4411468910';
  static const String iosTestAppOpen = 'ca-app-pub-3940256099942544/5575463023';
}
