import 'dart:async';

import 'package:deen_companion/features/ads/data/datasources/app_open_ad_datasource.dart';
import 'package:deen_companion/features/ads/data/datasources/banner_ad_datasource.dart';
import 'package:deen_companion/features/ads/data/datasources/interstitial_ad_datasource.dart';
import 'package:deen_companion/features/ads/data/datasources/mobile_ads_initializer.dart';
import 'package:deen_companion/features/ads/data/repositories/ads_repository_impl.dart';
import 'package:deen_companion/features/ads/data/services/ad_unit_resolver.dart';
import 'package:deen_companion/features/ads/domain/entities/remote_ads_config.dart';
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

  late FakeConfigStore config;
  late FakeConsent consent;
  late DateTime clock;

  AdsRepositoryImpl make([
    ResolvedAdUnit resolved = const ResolvedAdUnit.test('unit-1'),
  ]) => AdsRepositoryImpl(
    initializer: init,
    adUnitResolver: StubResolver(resolved),
    config: config,
    consent: consent,
    now: () => clock,
    bannerDataSource: banner,
    interstitialDataSource: interstitialSrc,
    appOpenDataSource: appOpenSrc,
  );

  setUp(() {
    init = MockInit();
    config = FakeConfigStore();
    consent = FakeConsent();
    clock = DateTime(2026, 11, 4, 9);
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
      await pumpEventQueue();
      expect(repo.isInterstitialReady, isTrue);
    });
  });

  group('gate (config → consent → SDK)', () {
    test('ads off in the config: no consent, no SDK, no requests', () async {
      config.current = RemoteAdsConfig.off;
      final repo = make();
      await repo.initialize();
      expect(await repo.loadBanner(width: 320), isNull);
      expect(await repo.preloadAppOpenAd(), isFalse);
      expect(consent.calls, 0);
      verifyNever(() => init.initialize());
      verifyNever(() => appOpenSrc.load(adUnitId: any(named: 'adUnitId')));
    });

    test('consent refusing ads: SDK never starts, nothing loads', () async {
      consent.canRequestAds = false;
      final repo = make();
      await repo.initialize();
      expect(await repo.preloadAppOpenAd(), isFalse);
      verifyNever(() => init.initialize());
      verifyNever(() => appOpenSrc.load(adUnitId: any(named: 'adUnitId')));
    });

    test('consent runs before the SDK and only once', () async {
      final repo = make();
      when(
        () => appOpenSrc.load(adUnitId: any(named: 'adUnitId')),
      ).thenAnswer((_) async => null);
      await repo.preloadAppOpenAd();
      await repo.preloadAppOpenAd();
      expect(consent.calls, 1);
      verify(() => init.initialize()).called(1);
    });

    test('remembers that a consent dialog was shown this launch', () async {
      consent.dialogShown = true;
      final repo = make();
      when(
        () => appOpenSrc.load(adUnitId: any(named: 'adUnitId')),
      ).thenAnswer((_) async => null);
      expect(repo.consentDialogShownThisLaunch, isFalse);
      await repo.preloadAppOpenAd();
      expect(repo.consentDialogShownThisLaunch, isTrue);
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

    test('show reports whether an ad was put on screen', () async {
      final repo = make();
      expect(repo.showInterstitial(onComplete: () {}), isFalse);
      await pumpEventQueue();
      expect(repo.isInterstitialReady, isTrue, reason: 'queued load finished');
      expect(repo.showInterstitial(onComplete: () {}), isTrue);
    });

    test('dismissal records when the last full-screen ad ended', () async {
      final repo = make();
      await repo.preloadInterstitial();
      expect(repo.lastFullScreenAdEndedAt, isNull);
      repo.showInterstitial(onComplete: () {});
      ad.fullScreenContentCallback!.onAdDismissedFullScreenContent!(ad);
      expect(repo.lastFullScreenAdEndedAt, clock);
    });

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

    test('waitUntilClosed holds until the ad is dismissed', () async {
      final repo = make();
      await repo.preloadAppOpenAd();
      var finished = false;
      final shown = repo
          .showAppOpenAdIfAvailable(waitUntilClosed: true)
          .then((v) => finished = v);
      await Future<void>.delayed(Duration.zero);
      expect(ad.showCount, 1);
      expect(finished, isFalse, reason: 'still on screen');
      ad.fullScreenContentCallback!.onAdDismissedFullScreenContent!(ad);
      expect(await shown, isTrue);
      expect(repo.lastFullScreenAdEndedAt, clock);
    });

    test('an ad older than 4 hours is discarded, not shown', () async {
      final repo = make();
      await repo.preloadAppOpenAd();
      clock = clock.add(const Duration(hours: 4, minutes: 1));
      expect(repo.isAppOpenAdReady, isFalse);
      expect(await repo.showAppOpenAdIfAvailable(), isFalse);
      expect(ad.disposeCount, 1);
    });

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
