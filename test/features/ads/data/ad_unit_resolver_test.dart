import 'package:deen_companion/features/ads/data/constants/ad_mob_ids.dart';
import 'package:deen_companion/features/ads/data/services/ad_unit_resolver.dart';
import 'package:deen_companion/features/ads/domain/entities/remote_ads_config.dart';
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
    setUp(() => expect(kDebugMode, isTrue));

    RemoteAdsConfig cfg({
      bool all = true,
      AdSlotConfig banner = const AdSlotConfig(enabled: true, unitId: 'b'),
      AdSlotConfig interstitial = const AdSlotConfig(
        enabled: true,
        unitId: 'i',
      ),
      AdSlotConfig appOpen = const AdSlotConfig(enabled: true, unitId: 'o'),
    }) => RemoteAdsConfig(
      adsEnabled: all,
      banner: banner,
      interstitial: interstitial,
      appOpen: appOpen,
    );

    test('enabled slots resolve to Google test units, never the server id', () {
      final resolver = AdUnitResolver(cfg);
      expect(resolver.banner().adUnitId, AdMobIds.testBanner);
      expect(resolver.interstitial().adUnitId, AdMobIds.testInterstitial);
      expect(resolver.appOpen().adUnitId, AdMobIds.testAppOpen);
      expect(resolver.banner().availability, AdAvailability.test);
    });

    test('the global switch off disables every type', () {
      final resolver = AdUnitResolver(() => cfg(all: false));
      expect(resolver.banner().shouldLoad, isFalse);
      expect(resolver.interstitial().shouldLoad, isFalse);
      expect(resolver.appOpen().shouldLoad, isFalse);
    });

    test('a type is off when disabled, or enabled without a unit id', () {
      final resolver = AdUnitResolver(
        () => cfg(
          banner: const AdSlotConfig(enabled: false, unitId: 'b'),
          interstitial: const AdSlotConfig(enabled: true, unitId: null),
          appOpen: const AdSlotConfig(enabled: true, unitId: '  '),
        ),
      );
      expect(resolver.banner().shouldLoad, isFalse);
      expect(resolver.interstitial().shouldLoad, isFalse);
      expect(resolver.appOpen().shouldLoad, isFalse);
    });

    test('with no config at all nothing is shown', () {
      final resolver = AdUnitResolver(() => RemoteAdsConfig.off);
      expect(resolver.banner().shouldLoad, isFalse);
    });

    test('reads the config each time, so a refresh takes effect', () {
      var current = RemoteAdsConfig.off;
      final resolver = AdUnitResolver(() => current);
      expect(resolver.banner().shouldLoad, isFalse);
      current = cfg();
      expect(resolver.banner().shouldLoad, isTrue);
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
        expect(id, matches(RegExp(r'^ca-app-pub-3940256099942544/\d{10}$')));
      }
    });

    test('android and ios test units are distinct', () {
      expect(AdMobIds.testBanner, isNot(AdMobIds.iosTestBanner));
      expect(AdMobIds.testInterstitial, isNot(AdMobIds.iosTestInterstitial));
      expect(AdMobIds.testAppOpen, isNot(AdMobIds.iosTestAppOpen));
    });
  });
}
