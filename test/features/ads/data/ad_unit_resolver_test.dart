import 'package:deen_companion/features/ads/data/constants/ad_mob_ids.dart';
import 'package:deen_companion/features/ads/data/constants/ads_config.dart';
import 'package:deen_companion/features/ads/data/services/ad_unit_resolver.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ResolvedAdUnit', () {
    test('real/test carry id and should load', () {
      const r = ResolvedAdUnit.real('abc');
      expect(r.availability, AdAvailability.real);
      expect(r.adUnitId, 'abc');
      expect(r.shouldLoad, isTrue);
      const t = ResolvedAdUnit.test('t');
      expect(t.availability, AdAvailability.test);
      expect(t.shouldLoad, isTrue);
    });

    test('disabled has no id and does not load', () {
      const d = ResolvedAdUnit.disabled();
      expect(d.availability, AdAvailability.disabled);
      expect(d.adUnitId, isNull);
      expect(d.shouldLoad, isFalse);
    });
  });

  group('AdUnitResolver (debug build under test)', () {
    const resolver = AdUnitResolver();

    setUp(() {
      // Guard: these assertions describe the debug-mode branch.
      expect(kDebugMode, isTrue);
    });

    test('config enables every format by default', () {
      expect(AdsConfig.adsEnabled, isTrue);
      expect(AdsConfig.bannerEnabled, isTrue);
      expect(AdsConfig.interstitialEnabled, isTrue);
      expect(AdsConfig.appOpenEnabled, isTrue);
    });

    test('banner resolves to Google test unit', () {
      final r = resolver.banner();
      expect(r.availability, AdAvailability.test);
      expect(r.adUnitId, AdMobIds.testBanner);
    });

    test('interstitial resolves to Google test unit', () {
      final r = resolver.interstitial();
      expect(r.availability, AdAvailability.test);
      expect(r.adUnitId, AdMobIds.testInterstitial);
    });

    test('app open resolves to Google test unit', () {
      final r = resolver.appOpen();
      expect(r.availability, AdAvailability.test);
      expect(r.adUnitId, AdMobIds.testAppOpen);
    });

    test('never picks a production id in debug', () {
      for (final r in [
        resolver.banner(),
        resolver.interstitial(),
        resolver.appOpen(),
      ]) {
        expect(
          r.adUnitId,
          isNot(AdMobIds.prodBanner.isEmpty ? '' : AdMobIds.prodBanner),
        );
        expect(r.adUnitId, startsWith('ca-app-pub-3940256099942544/'));
      }
    });
  });

  group('AdMobIds', () {
    test('test units use the public Google test publisher id', () {
      for (final id in [
        AdMobIds.testBanner,
        AdMobIds.testInterstitial,
        AdMobIds.testAppOpen,
        AdMobIds.iosTestBanner,
        AdMobIds.iosTestInterstitial,
        AdMobIds.iosTestAppOpen,
      ]) {
        expect(id, matches(RegExp(r'^ca-app-pub-\d{16}/\d{10}$')));
      }
    });

    test('android and ios test units are distinct', () {
      expect(AdMobIds.testBanner, isNot(AdMobIds.iosTestBanner));
      expect(AdMobIds.testInterstitial, isNot(AdMobIds.iosTestInterstitial));
      expect(AdMobIds.testAppOpen, isNot(AdMobIds.iosTestAppOpen));
    });

    test('production ids are not committed (empty without dart-define)', () {
      expect(AdMobIds.prodBanner, isEmpty);
      expect(AdMobIds.prodInterstitial, isEmpty);
      expect(AdMobIds.prodAppOpen, isEmpty);
    });
  });
}
