import 'package:deen_companion/features/ads/data/services/ad_unit_resolver.dart';
import 'package:deen_companion/features/ads/data/services/ads_config_store.dart';
import 'package:deen_companion/features/ads/data/services/ads_consent.dart';
import 'package:deen_companion/features/ads/domain/entities/remote_ads_config.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter_test/flutter_test.dart';

/// Resolver returning canned results, so repository logic can be tested for
/// the disabled / real / test cases independent of build mode.
class StubResolver extends AdUnitResolver {
  final ResolvedAdUnit result;
  StubResolver(this.result) : super(() => RemoteAdsConfig.off);

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

const allOn = RemoteAdsConfig(
  adsEnabled: true,
  banner: AdSlotConfig(enabled: true, unitId: 'b'),
  interstitial: AdSlotConfig(enabled: true, unitId: 'i'),
  appOpen: AdSlotConfig(enabled: true, unitId: 'o'),
);

/// A config store that is always ready with [current].
class FakeConfigStore extends Fake implements AdsConfigStore {
  @override
  RemoteAdsConfig current;
  FakeConfigStore([this.current = allOn]);

  @override
  Future<void> get ready => Future.value();

  @override
  Future<void> refreshIfStale() async {}
}

class FakeConsent implements AdsConsent {
  bool canRequestAds = true;
  bool dialogShown = false;
  int calls = 0;

  @override
  Future<AdsConsentResult> gather() async {
    calls++;
    return AdsConsentResult(
      canRequestAds: canRequestAds,
      dialogShown: dialogShown,
    );
  }
}
