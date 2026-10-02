import 'dart:async';

import 'package:deen_companion/features/ads/data/datasources/app_open_ad_datasource.dart';
import 'package:deen_companion/features/ads/data/datasources/banner_ad_datasource.dart';
import 'package:deen_companion/features/ads/data/datasources/interstitial_ad_datasource.dart';
import 'package:deen_companion/features/ads/data/datasources/mobile_ads_initializer.dart';
import 'package:deen_companion/features/ads/data/repositories/ads_repository_impl.dart';
import 'package:deen_companion/features/ads/data/services/ad_unit_resolver.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:mocktail/mocktail.dart';

import 'ads_helpers.dart';

class MockInit extends Mock implements MobileAdsInitializer {}

class MockBanner extends Mock implements BannerAdDataSource {}

class MockInterstitialSource extends Mock implements InterstitialAdDataSource {}

class MockAppOpenSource extends Mock implements AppOpenAdDataSource {}

void main() {
  late MockInit init;
  late MockBanner banner;
  late MockInterstitialSource interstitialSrc;
  late MockAppOpenSource appOpenSrc;

  AdsRepositoryImpl make([
    ResolvedAdUnit resolved = const ResolvedAdUnit.test('unit-1'),
  ]) => AdsRepositoryImpl(
    initializer: init,
    adUnitResolver: StubResolver(resolved),
    bannerDataSource: banner,
    interstitialDataSource: interstitialSrc,
    appOpenDataSource: appOpenSrc,
  );

  setUp(() {
    init = MockInit();
    banner = MockBanner();
    interstitialSrc = MockInterstitialSource();
    appOpenSrc = MockAppOpenSource();
    when(() => init.initialize()).thenAnswer((_) async {});
  });

  group('initialize', () {
    test(
      'initializes the SDK only once however often it is requested',
      () async {
        final repo = make();
        when(
          () => interstitialSrc.load(adUnitId: any(named: 'adUnitId')),
        ).thenAnswer((_) async => null);
        await repo.initialize();
        await repo.initialize();
        await repo.preloadInterstitial();
        verify(() => init.initialize()).called(1);
      },
    );

    test('SDK init failure does not wedge later requests', () async {
      when(() => init.initialize()).thenThrow(StateError('sdk'));
      when(
        () => interstitialSrc.load(adUnitId: any(named: 'adUnitId')),
      ).thenAnswer((_) async => FakeInterstitialAd());
      final repo = make();
      await repo.initialize();
      await repo.preloadInterstitial();
      expect(repo.isInterstitialReady, isTrue);
    });
  });

  group('banner', () {
    test(
      'disabled resolution returns null without touching datasource',
      () async {
        final repo = make(const ResolvedAdUnit.disabled());
        expect(await repo.loadBanner(width: 320), isNull);
        verifyNever(
          () => banner.load(
            width: any(named: 'width'),
            adUnitId: any(named: 'adUnitId'),
          ),
        );
      },
    );

    test('passes width and resolved unit id to datasource', () async {
      when(
        () => banner.load(
          width: any(named: 'width'),
          adUnitId: any(named: 'adUnitId'),
        ),
      ).thenAnswer((_) async => null);
      final repo = make(const ResolvedAdUnit.real('real-banner'));
      expect(await repo.loadBanner(width: 411.5), isNull);
      verify(
        () => banner.load(width: 411.5, adUnitId: 'real-banner'),
      ).called(1);
    });
  });

  group('interstitial', () {
    late FakeInterstitialAd ad;
    setUp(() {
      ad = FakeInterstitialAd();
      when(
        () => interstitialSrc.load(adUnitId: any(named: 'adUnitId')),
      ).thenAnswer((_) async => ad);
    });

    test('not ready until preloaded; preload uses resolved id', () async {
      final repo = make(const ResolvedAdUnit.real('int-real'));
      expect(repo.isInterstitialReady, isFalse);
      await repo.preloadInterstitial();
      expect(repo.isInterstitialReady, isTrue);
      verify(() => interstitialSrc.load(adUnitId: 'int-real')).called(1);
    });

    test('disabled resolution never loads', () async {
      final repo = make(const ResolvedAdUnit.disabled());
      await repo.preloadInterstitial();
      expect(repo.isInterstitialReady, isFalse);
      verifyNever(() => interstitialSrc.load(adUnitId: any(named: 'adUnitId')));
    });

    test('failed load leaves nothing ready and allows a retry', () async {
      when(
        () => interstitialSrc.load(adUnitId: any(named: 'adUnitId')),
      ).thenAnswer((_) async => null);
      final repo = make();
      await repo.preloadInterstitial();
      expect(repo.isInterstitialReady, isFalse);
      await repo.preloadInterstitial();
      verify(
        () => interstitialSrc.load(adUnitId: any(named: 'adUnitId')),
      ).called(2);
    });

    test('preload is skipped while an ad is already ready', () async {
      final repo = make();
      await repo.preloadInterstitial();
      await repo.preloadInterstitial();
      verify(
        () => interstitialSrc.load(adUnitId: any(named: 'adUnitId')),
      ).called(1);
    });

    test(
      'show with nothing ready completes immediately and queues a load',
      () async {
        when(
          () => interstitialSrc.load(adUnitId: any(named: 'adUnitId')),
        ).thenAnswer((_) async => null);
        final repo = make();
        var done = 0;
        repo.showInterstitial(onComplete: () => done++);
        expect(done, 1);
        await Future<void>.delayed(Duration.zero);
        verify(
          () => interstitialSrc.load(adUnitId: any(named: 'adUnitId')),
        ).called(1);
      },
    );

    test('show runs onComplete only after dismissal, exactly once', () async {
      final repo = make();
      await repo.preloadInterstitial();
      var done = 0;
      repo.showInterstitial(onComplete: () => done++);
      expect(ad.showCount, 1);
      expect(done, 0, reason: 'must wait for dismissal');
      expect(repo.isDisplayingFullScreenAd, isTrue);

      // Both callbacks fire (dismissed then failed): still once.
      ad.fullScreenContentCallback!.onAdDismissedFullScreenContent!(ad);
      ad.fullScreenContentCallback!.onAdDismissedFullScreenContent!(ad);
      expect(done, 1);
      expect(repo.isDisplayingFullScreenAd, isFalse);
      expect(ad.disposeCount, greaterThanOrEqualTo(1));
      expect(repo.isInterstitialReady, isFalse);
    });

    test('dismissal triggers a refill', () async {
      final repo = make();
      await repo.preloadInterstitial();
      repo.showInterstitial(onComplete: () {});
      ad.fullScreenContentCallback!.onAdDismissedFullScreenContent!(ad);
      await Future<void>.delayed(Duration.zero);
      verify(
        () => interstitialSrc.load(adUnitId: any(named: 'adUnitId')),
      ).called(2);
    });

    test('failed show still completes and discards the ad', () async {
      final repo = make();
      await repo.preloadInterstitial();
      var done = 0;
      repo.showInterstitial(onComplete: () => done++);
      ad.fullScreenContentCallback!.onAdFailedToShowFullScreenContent!(
        ad,
        AdError(1, 'domain', 'msg'),
      );
      expect(done, 1);
      expect(repo.isDisplayingFullScreenAd, isFalse);
      expect(repo.isInterstitialReady, isFalse);
    });

    test(
      'a second show while one is on screen completes without stacking',
      () async {
        final repo = make();
        await repo.preloadInterstitial();
        repo.showInterstitial(onComplete: () {});
        var second = 0;
        repo.showInterstitial(onComplete: () => second++);
        expect(second, 1);
        expect(ad.showCount, 1);
      },
    );

    test('dispose releases a loaded ad', () async {
      final repo = make();
      await repo.preloadInterstitial();
      repo.dispose();
      expect(ad.disposeCount, 1);
      expect(repo.isInterstitialReady, isFalse);
    });
  });

  group('app open', () {
    late FakeAppOpenAd ad;
    setUp(() {
      ad = FakeAppOpenAd();
      when(
        () => appOpenSrc.load(adUnitId: any(named: 'adUnitId')),
      ).thenAnswer((_) async => ad);
    });

    test('preload returns true and marks ready', () async {
      final repo = make();
      expect(repo.isAppOpenAdReady, isFalse);
      expect(await repo.preloadAppOpenAd(), isTrue);
      expect(repo.isAppOpenAdReady, isTrue);
    });

    test('preload when already ready does not reload', () async {
      final repo = make();
      await repo.preloadAppOpenAd();
      expect(await repo.preloadAppOpenAd(), isTrue);
      verify(() => appOpenSrc.load(adUnitId: any(named: 'adUnitId'))).called(1);
    });

    test('concurrent preloads share one in-flight load', () async {
      final completer = Completer<AppOpenAd?>();
      when(
        () => appOpenSrc.load(adUnitId: any(named: 'adUnitId')),
      ).thenAnswer((_) => completer.future);
      final repo = make();
      final first = repo.preloadAppOpenAd();
      // Let the first call get past SDK init and into the load.
      await Future<void>.delayed(Duration.zero);
      final second = repo.preloadAppOpenAd();
      completer.complete(ad);
      expect(await first, isTrue);
      expect(await second, isTrue);
      verify(() => appOpenSrc.load(adUnitId: any(named: 'adUnitId'))).called(1);
    });

    test('failed load returns false and a later retry can succeed', () async {
      when(
        () => appOpenSrc.load(adUnitId: any(named: 'adUnitId')),
      ).thenAnswer((_) async => null);
      final repo = make();
      expect(await repo.preloadAppOpenAd(), isFalse);
      expect(repo.isAppOpenAdReady, isFalse);
      when(
        () => appOpenSrc.load(adUnitId: any(named: 'adUnitId')),
      ).thenAnswer((_) async => ad);
      expect(await repo.preloadAppOpenAd(), isTrue);
    });

    test('disabled resolution returns false without loading', () async {
      final repo = make(const ResolvedAdUnit.disabled());
      expect(await repo.preloadAppOpenAd(), isFalse);
      verifyNever(() => appOpenSrc.load(adUnitId: any(named: 'adUnitId')));
    });

    test('show returns false when nothing is ready', () async {
      expect(await make().showAppOpenAdIfAvailable(), isFalse);
    });

    test(
      'show returns true, flags full-screen, dismissal clears and refills',
      () async {
        final repo = make();
        await repo.preloadAppOpenAd();
        expect(await repo.showAppOpenAdIfAvailable(), isTrue);
        expect(ad.showCount, 1);
        expect(repo.isDisplayingFullScreenAd, isTrue);

        ad.fullScreenContentCallback!.onAdDismissedFullScreenContent!(ad);
        expect(repo.isDisplayingFullScreenAd, isFalse);
        expect(repo.isAppOpenAdReady, isFalse);
        await Future<void>.delayed(Duration.zero);
        verify(
          () => appOpenSrc.load(adUnitId: any(named: 'adUnitId')),
        ).called(2);
      },
    );

    test('will not show over an interstitial that is on screen', () async {
      when(
        () => interstitialSrc.load(adUnitId: any(named: 'adUnitId')),
      ).thenAnswer((_) async => FakeInterstitialAd());
      final repo = make();
      await repo.preloadAppOpenAd();
      await repo.preloadInterstitial();
      repo.showInterstitial(onComplete: () {});
      expect(repo.isDisplayingFullScreenAd, isTrue);
      expect(await repo.showAppOpenAdIfAvailable(), isFalse);
      expect(ad.showCount, 0);
    });
  });
}
