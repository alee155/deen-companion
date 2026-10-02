/// Raw AdMob ad unit ID strings — nothing else. No decision logic lives
/// here on purpose: which of these actually gets used (real, test, or
/// neither) is resolved centrally by `AdUnitResolver`
/// (`data/services/ad_unit_resolver.dart`), which is the only file that
/// reads these constants. Production IDs are build-time configuration, not
/// source.
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
  /// The Application ID is injected into the manifest from the gitignored
  /// `android/admob.properties` (see `android/app/build.gradle.kts`).
  static const String applicationId = 'ca-app-pub-3940256099942544~3347511713';

  // ── Real production ad units ──────────────────────────────────────
  // Supplied at build time and never committed:
  //   flutter build appbundle --dart-define-from-file=config/prod.json
  // (see config/prod.example.json). When a value is absent it is empty and
  // `AdUnitResolver` treats that format as disabled in release builds.
  static const String prodBanner = String.fromEnvironment('ADMOB_BANNER_ID');
  static const String prodInterstitial = String.fromEnvironment(
    'ADMOB_INTERSTITIAL_ID',
  );
  static const String prodAppOpen = String.fromEnvironment(
    'ADMOB_APP_OPEN_ID',
  );

  // ── Google's public test ad units ─────────────────────────────────
  // Safe to ship, always fill, always show a creative clearly labelled
  // "Test Ad". Same values Google publishes in its own quick-start docs:
  // https://developers.google.com/admob/flutter/test-ads
  static const String testBanner = 'ca-app-pub-3940256099942544/9214589741';
  static const String testInterstitial =
      'ca-app-pub-3940256099942544/1033173712';
  static const String testAppOpen = 'ca-app-pub-3940256099942544/9257395921';

  // iOS equivalents — Google's test units are platform-specific.
  static const String iosTestBanner = 'ca-app-pub-3940256099942544/2934735716';
  static const String iosTestInterstitial =
      'ca-app-pub-3940256099942544/4411468910';
  static const String iosTestAppOpen = 'ca-app-pub-3940256099942544/5575463023';
}
