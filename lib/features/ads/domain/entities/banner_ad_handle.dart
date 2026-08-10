import 'package:google_mobile_ads/google_mobile_ads.dart';

/// A successfully loaded banner ad, ready to be rendered with [AdWidget].
///
/// This is deliberately the one place in the ads feature where a domain
/// type holds a third-party SDK object directly. A "clean" wrapper that
/// copied [BannerAd]'s width/height/dispose surface under new names would
/// add a layer without adding a boundary — [AdWidget] needs the actual
/// [BannerAd] instance to render, there's no domain-safe substitute for it.
/// Everywhere else in this feature (placements, load status, frequency
/// logic, ad-unit resolution) stays free of `google_mobile_ads` imports.
class BannerAdHandle {
  final BannerAd ad;
  final AdSize size;

  const BannerAdHandle({required this.ad, required this.size});

  /// Releases the underlying platform ad view. Safe to call more than
  /// once — [BannerAd.dispose] is itself idempotent.
  void dispose() => ad.dispose();
}
