import 'package:deen_companion/features/ads/presentation/providers/interstitial_ad_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// An interstitial service that never shows anything, for tests that open
/// snaps and have nothing to do with ads.
class _NoInterstitials extends Fake implements InterstitialAdService {
  @override
  Future<void> maybeShow(
    InterstitialPlacement placement, {
    String? prayer,
  }) async {}
}

final noInterstitials = interstitialAdServiceProvider.overrideWithValue(
  _NoInterstitials(),
);

/// For test files that build a container with `overrides: [...]`.
List<Override> withNoInterstitials([List<Override> others = const []]) => [
  ...others,
  noInterstitials,
];
