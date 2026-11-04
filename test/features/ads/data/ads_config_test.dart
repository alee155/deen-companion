import 'dart:convert';

import 'package:deen_companion/core/constants/app_constants.dart';
import 'package:deen_companion/features/ads/data/datasources/ads_config_remote_datasource.dart';
import 'package:deen_companion/features/ads/data/services/ads_config_store.dart';
import 'package:deen_companion/features/ads/domain/entities/remote_ads_config.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/in_memory_storage_service.dart';

class FakeRemote extends AdsConfigRemoteDataSource {
  FakeRemote(this.answer, {this.latency = Duration.zero});
  AdsConfigFetch? answer;
  final Duration latency;
  int calls = 0;
  String? lastEtag;
  String? lastPlatform;

  @override
  Future<AdsConfigFetch?> fetch({
    required String appKey,
    required String platform,
    String? etag,
  }) async {
    calls++;
    lastEtag = etag;
    lastPlatform = platform;
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    return answer;
  }
}

const _json = {
  'app': 'deen_companion',
  'platform': 'android',
  'ads_enabled': true,
  'ads': {
    'banner': {'enabled': true, 'unit_id': 'ca-app-pub-x/banner'},
    'interstitial': {'enabled': false, 'unit_id': null},
    'app_open': {'enabled': true, 'unit_id': 'ca-app-pub-x/open'},
  },
  'config_version': 7,
  'ttl_seconds': 3600,
};

void main() {
  const box = AppConstants.settingsBoxName;
  late InMemoryStorageService storage;
  late DateTime clock;

  setUp(() {
    storage = InMemoryStorageService();
    clock = DateTime(2026, 11, 4, 9);
  });

  AdsConfigStore store(FakeRemote remote) => AdsConfigStore(
    remote: remote,
    storage: storage,
    platform: 'ios',
    now: () => clock,
  );

  Future<void> seedCache({required Duration age, String etag = 'W/"1"'}) =>
      storage.put(
        box,
        AppConstants.adsConfigCacheKey,
        jsonEncode({
          'config': RemoteAdsConfig.fromJson(_json).toJson(),
          'fetchedAt': clock.subtract(age).millisecondsSinceEpoch,
          'etag': etag,
        }),
      );

  group('RemoteAdsConfig', () {
    test('parses the service response', () {
      final c = RemoteAdsConfig.fromJson(_json);
      expect(c.adsEnabled, isTrue);
      expect(c.banner.usable, isTrue);
      expect(c.banner.unitId, 'ca-app-pub-x/banner');
      expect(c.interstitial.usable, isFalse);
      expect(c.appOpen.usable, isTrue);
      expect(c.configVersion, 7);
    });

    test('a missing or malformed body means everything off', () {
      final c = RemoteAdsConfig.fromJson({'ads': 'nope'});
      expect(c.adsEnabled, isFalse);
      expect(c.banner.usable, isFalse);
      expect(c.ttlSeconds, RemoteAdsConfig.defaultTtlSeconds);
    });

    test('round-trips through json', () {
      final c = RemoteAdsConfig.fromJson(
        RemoteAdsConfig.fromJson(_json).toJson(),
      );
      expect(c.appOpen.unitId, 'ca-app-pub-x/open');
      expect(c.configVersion, 7);
    });
  });

  group('AdsConfigStore', () {
    test('no ads until anything is known', () {
      expect(store(FakeRemote(null)).current.adsEnabled, isFalse);
    });

    test('first launch: fetches, saves, and uses the answer', () async {
      final remote = FakeRemote(
        AdsConfigFetch(config: RemoteAdsConfig.fromJson(_json), etag: 'W/"a"'),
      );
      final s = store(remote);
      await s.ready;
      expect(remote.calls, 1);
      expect(remote.lastPlatform, 'ios');
      expect(s.current.banner.usable, isTrue);
      expect(
        storage.get<String>(box, AppConstants.adsConfigCacheKey),
        isNotNull,
      );
    });

    test('first launch with the service down: no ads, no crash', () async {
      final s = store(FakeRemote(null));
      await s.ready;
      expect(s.current.adsEnabled, isFalse);
    });

    test('a fresh saved copy is used without a request', () async {
      await seedCache(age: const Duration(minutes: 10));
      final remote = FakeRemote(null);
      final s = store(remote);
      await s.ready;
      expect(remote.calls, 0);
      expect(s.current.banner.usable, isTrue);
    });

    test('a stale saved copy is used at once and refreshed behind', () async {
      await seedCache(age: const Duration(hours: 2));
      final remote = FakeRemote(
        const AdsConfigFetch(config: RemoteAdsConfig.off, etag: 'W/"2"'),
        latency: const Duration(milliseconds: 20),
      );
      final s = store(remote);
      await s.ready;
      expect(s.current.banner.usable, isTrue, reason: 'saved copy, instantly');
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(remote.calls, 1);
      expect(remote.lastEtag, 'W/"1"', reason: 'sends the saved ETag');
      expect(s.current.adsEnabled, isFalse, reason: 'server switched it off');
    });

    test('304 keeps the config and restarts the TTL', () async {
      await seedCache(age: const Duration(hours: 2));
      final remote = FakeRemote(const AdsConfigFetch(notModified: true));
      final s = store(remote);
      await s.ready;
      await Future<void>.delayed(Duration.zero);
      expect(s.current.banner.usable, isTrue);
      await s.refreshIfStale();
      expect(remote.calls, 1, reason: 'no longer stale');
    });

    test('a failed refresh keeps the saved copy', () async {
      await seedCache(age: const Duration(hours: 2));
      final remote = FakeRemote(null);
      final s = store(remote);
      await s.ready;
      await Future<void>.delayed(Duration.zero);
      expect(s.current.banner.usable, isTrue);
    });

    test('refreshIfStale fetches only after the TTL', () async {
      await seedCache(age: const Duration(minutes: 5));
      final remote = FakeRemote(
        AdsConfigFetch(config: RemoteAdsConfig.fromJson(_json)),
      );
      final s = store(remote);
      await s.refreshIfStale();
      expect(remote.calls, 0);
      clock = clock.add(const Duration(hours: 2));
      await s.refreshIfStale();
      expect(remote.calls, 1);
    });

    test('an unreadable saved copy is ignored and refetched', () async {
      await storage.put(box, AppConstants.adsConfigCacheKey, 'not json');
      final remote = FakeRemote(
        AdsConfigFetch(config: RemoteAdsConfig.fromJson(_json)),
      );
      final s = store(remote);
      await s.ready;
      expect(remote.calls, 1);
      expect(s.current.banner.usable, isTrue);
    });

    test('forceTestAds switches every ad type on, still fetching', () async {
      final remote = FakeRemote(AdsConfigFetch(config: RemoteAdsConfig.off));
      final s = AdsConfigStore(
        remote: remote,
        storage: storage,
        platform: 'ios',
        now: () => clock,
        forceTestAds: true,
      );
      await s.ready;
      expect(remote.calls, 1);
      expect(s.current.adsEnabled, isTrue);
      expect(s.current.banner.usable, isTrue);
      expect(s.current.interstitial.usable, isTrue);
      expect(s.current.appOpen.usable, isTrue);
    });

    test('without forceTestAds an off answer stays off', () async {
      final remote = FakeRemote(AdsConfigFetch(config: RemoteAdsConfig.off));
      final s = store(remote);
      await s.ready;
      expect(s.current.adsEnabled, isFalse);
    });
  });
}
