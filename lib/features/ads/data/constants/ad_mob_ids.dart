/// Raw AdMob ad unit ID strings — nothing else. No decision logic lives
/// here on purpose: which of these actually gets used (real, test, or
/// neither) is resolved centrally by `AdUnitResolver`
/// (`data/services/ad_unit_resolver.dart`), which is the only file that
/// reads these constants.
///
/// Android-only, per the app's current target — there is deliberately no
/// platform branching here. If iOS is ever targeted, add an `_iosBanner`
/// etc. set and branch in `AdUnitResolver` the same way this used to
/// branch on `Platform.isIOS` before ad unit selection moved to Remote
/// Config.
class AdMobIds {
  AdMobIds._();

  /// The AdMob **Application ID** (the `~`-suffixed one) — this is the
  /// value declared in `android/app/src/main/AndroidManifest.xml`'s
  /// `com.google.android.gms.ads.APPLICATION_ID` meta-data. It identifies
  /// which AdMob account owns the SDK instance and is *not* something
  /// this resolver swaps per ad type — per Google's own guidance, the
  /// real Application ID is used at all times, even on builds that are
  /// currently serving test ad *units*. It's listed here only for
  /// reference/documentation; nothing in Dart reads it, since it only
  /// ever needs to exist in the manifest.
  static const String applicationId = 'ca-app-pub-1880428028238946~8005314189';

  // ── Real production ad units ──────────────────────────────────────
  static const String prodBanner = 'ca-app-pub-1880428028238946/8659920306';
  static const String prodInterstitial =
      'ca-app-pub-1880428028238946/8539932588';
  static const String prodAppOpen = 'ca-app-pub-1880428028238946/1056762456';

  // ── Google's public test ad units ─────────────────────────────────
  // Safe to ship, always fill, always show a creative clearly labelled
  // "Test Ad". Same values Google publishes in its own quick-start docs:
  // https://developers.google.com/admob/flutter/test-ads
  static const String testBanner = 'ca-app-pub-3940256099942544/9214589741';
  static const String testInterstitial =
      'ca-app-pub-3940256099942544/1033173712';
  static const String testAppOpen = 'ca-app-pub-3940256099942544/9257395921';
}
