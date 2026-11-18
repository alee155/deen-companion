import 'package:google_mobile_ads/google_mobile_ads.dart';

/// What Deen Companion lets its ads be, in one place.
///
/// The SDK can only cap how mature an ad may be. Blocking whole categories
/// (dating, gambling, alcohol and so on) and single advertisers is done in the
/// AdMob console, for the Android and the iOS app separately.
class AdFilterPolicy {
  const AdFilterPolicy._();

  /// The strictest rating: only ads rated G are served. Ratings are
  /// cumulative, so PG, T and MA ads are all excluded. A rating sent from the
  /// app overrides the one set in the AdMob console.
  static final String maxRating = MaxAdContentRating.g;

  /// Applied once, before the SDK starts, so no request goes out without it.
  static RequestConfiguration requestConfiguration() => RequestConfiguration(
    maxAdContentRating: maxRating,
    tagForChildDirectedTreatment: TagForChildDirectedTreatment.no,
    tagForUnderAgeOfConsent: TagForUnderAgeOfConsent.no,
  );

  /// The request every banner, interstitial and App Open ad is made with, so
  /// anything added later (a flag, a hint) reaches all three.
  static AdRequest request() => const AdRequest();
}
