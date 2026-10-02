import 'package:deen_companion/features/ads/data/services/ad_unit_resolver.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter_test/flutter_test.dart';

/// Resolver returning canned results, so repository logic can be tested for
/// the disabled / real / test cases independent of build mode.
class StubResolver extends AdUnitResolver {
  final ResolvedAdUnit result;
  const StubResolver(this.result);

  @override
  ResolvedAdUnit banner() => result;
  @override
  ResolvedAdUnit interstitial() => result;
  @override
  ResolvedAdUnit appOpen() => result;
}

/// Hand-written interstitial that records show/dispose and lets tests
/// trigger the SDK callbacks.
class FakeInterstitialAd extends Fake implements InterstitialAd {
  @override
  FullScreenContentCallback<InterstitialAd>? fullScreenContentCallback;
  int showCount = 0;
  int disposeCount = 0;

  @override
  Future<void> show() async {
    showCount++;
    fullScreenContentCallback?.onAdShowedFullScreenContent?.call(this);
  }

  @override
  Future<void> dispose() async => disposeCount++;
}

class FakeAppOpenAd extends Fake implements AppOpenAd {
  @override
  FullScreenContentCallback<AppOpenAd>? fullScreenContentCallback;
  int showCount = 0;
  int disposeCount = 0;

  @override
  Future<void> show() async {
    showCount++;
    fullScreenContentCallback?.onAdShowedFullScreenContent?.call(this);
  }

  @override
  Future<void> dispose() async => disposeCount++;
}
