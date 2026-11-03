import 'dart:async';
import 'dart:math';

import 'package:deen_companion/core/constants/app_constants.dart';
import 'package:deen_companion/core/storage/local_storage_service.dart';
import 'package:deen_companion/features/ads/domain/entities/banner_ad_handle.dart';
import 'package:deen_companion/features/ads/domain/repositories/ads_repository.dart';
import 'package:deen_companion/features/ads/domain/snap_ad_plan.dart';
import 'package:deen_companion/features/ads/presentation/providers/ads_providers.dart';
import 'package:deen_companion/features/ads/presentation/providers/app_open_ad_manager.dart';
import 'package:deen_companion/features/ads/presentation/providers/interstitial_ad_service.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/in_memory_storage_service.dart';
import '../data/ads_helpers.dart';

class FakeAdsRepository implements AdsRepository {
  bool interstitialReady = false;
  bool displaying = false;
  bool appOpenReady = false;
  bool preloadAppOpenResult = false;
  bool showAppOpenResult = true;
  bool consentDialog = false;
  DateTime? lastEnded;

  /// When set, [preloadAppOpenAd] waits on it (a slow ad network).
  Completer<bool>? preloadGate;

  int showInterstitialCalls = 0;
  int showAppOpenCalls = 0;
  bool lastWaitUntilClosed = false;
  int preloadAppOpenCalls = 0;
  int preloadInterstitialCalls = 0;
  int initializeCalls = 0;
  bool disposed = false;

  @override
  Future<void> initialize() async => initializeCalls++;

  @override
  DateTime? get lastFullScreenAdEndedAt => lastEnded;

  @override
  bool get consentDialogShownThisLaunch => consentDialog;

  @override
  Future<BannerAdHandle?> loadBanner({required double width}) async => null;

  @override
  bool get isInterstitialReady => interstitialReady;

  @override
  Future<void> preloadInterstitial() async => preloadInterstitialCalls++;

  @override
  bool showInterstitial({required AdFlowComplete onComplete}) {
    if (!interstitialReady) {
      onComplete();
      return false;
    }
    showInterstitialCalls++;
    onComplete();
    return true;
  }

  @override
  bool get isDisplayingFullScreenAd => displaying;

  @override
  bool get isAppOpenAdReady => appOpenReady;

  @override
  Future<bool> preloadAppOpenAd() async {
    preloadAppOpenCalls++;
    final gate = preloadGate;
    if (gate != null) return gate.future;
    if (preloadAppOpenResult) appOpenReady = true;
    return preloadAppOpenResult;
  }

  @override
  Future<bool> showAppOpenAdIfAvailable({bool waitUntilClosed = false}) async {
    showAppOpenCalls++;
    lastWaitUntilClosed = waitUntilClosed;
    return showAppOpenResult;
  }

  @override
  void dispose() => disposed = true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const box = AppConstants.settingsBoxName;

  late FakeAdsRepository repo;
  late InMemoryStorageService storage;
  late DateTime clock;

  ProviderContainer makeContainer() {
    final c = ProviderContainer(
      overrides: [
        adsRepositoryProvider.overrideWithValue(repo),
        adsConfigStoreProvider.overrideWithValue(FakeConfigStore()),
        localStorageServiceProvider.overrideWithValue(storage),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  setUp(() {
    repo = FakeAdsRepository();
    storage = InMemoryStorageService();
    clock = DateTime(2026, 11, 4, 9);
  });

  group('adsInitializationProvider', () {
    test('initializes the repository', () async {
      final container = makeContainer();
      await container.read(adsInitializationProvider.future);
      expect(repo.initializeCalls, 1);
    });
  });

  group('AppOpenAdManager', () {
    late AppOpenAdManager manager;

    setUp(() {
      final c = ProviderContainer(
        overrides: [
          adsRepositoryProvider.overrideWithValue(repo),
          adsConfigStoreProvider.overrideWithValue(FakeConfigStore()),
          localStorageServiceProvider.overrideWithValue(storage),
        ],
      );
      addTearDown(c.dispose);
      final p = Provider((ref) => AppOpenAdManager(ref, now: () => clock));
      manager = c.read(p);
      addTearDown(manager.dispose);
    });

    Future<void> returningUser() =>
        storage.put(box, AppConstants.authGateSeenKey, true);

    test('start preloads once and is idempotent', () {
      manager.start();
      manager.start();
      expect(repo.preloadAppOpenCalls, 1);
    });

    group('cold start', () {
      test(
        'a ready ad is shown over the splash and the splash waits',
        () async {
          await returningUser();
          repo.appOpenReady = true;
          await manager.showOnColdStart();
          expect(repo.showAppOpenCalls, 1);
          expect(repo.lastWaitUntilClosed, isTrue, reason: 'Home opens after');
          expect(
            storage.get<int>(box, AppConstants.appOpenAdLastShownKey),
            clock.millisecondsSinceEpoch,
          );
        },
      );

      test('an ad that finishes loading within the budget is shown', () async {
        await returningUser();
        repo.preloadAppOpenResult = true;
        await manager.showOnColdStart();
        expect(repo.showAppOpenCalls, 1);
      });

      test('THE FIX: an ad still loading when the budget ends is not shown '
          'late, and the splash is released on time', () async {
        await returningUser();
        repo.preloadGate = Completer<bool>(); // the network is slow
        final watch = Stopwatch()..start();
        await manager.showOnColdStart(budget: const Duration(milliseconds: 60));
        watch.stop();
        expect(repo.showAppOpenCalls, 0);
        expect(watch.elapsedMilliseconds, lessThan(1000));

        // The ad arrives after Home is already up: still nothing.
        repo.appOpenReady = true;
        repo.preloadGate!.complete(true);
        await Future<void>.delayed(Duration.zero);
        expect(repo.showAppOpenCalls, 0);
      });

      test('a failed load just moves on', () async {
        await returningUser();
        repo.preloadAppOpenResult = false;
        await manager.showOnColdStart();
        expect(repo.showAppOpenCalls, 0);
      });

      test('never on the very first launch', () async {
        repo.appOpenReady = true;
        await manager.showOnColdStart();
        expect(repo.showAppOpenCalls, 0);
        expect(repo.preloadAppOpenCalls, 0);
      });

      test('not within 4 hours of the last one, again after', () async {
        await returningUser();
        repo.appOpenReady = true;
        await storage.put(
          box,
          AppConstants.appOpenAdLastShownKey,
          clock.subtract(const Duration(hours: 1)).millisecondsSinceEpoch,
        );
        await manager.showOnColdStart();
        expect(repo.showAppOpenCalls, 0);

        await storage.put(
          box,
          AppConstants.appOpenAdLastShownKey,
          clock.subtract(const Duration(hours: 5)).millisecondsSinceEpoch,
        );
        await manager.showOnColdStart();
        expect(repo.showAppOpenCalls, 1);
      });

      test(
        'skipped on a launch that showed a consent or tracking prompt',
        () async {
          await returningUser();
          repo.appOpenReady = true;
          repo.consentDialog = true;
          await manager.showOnColdStart();
          expect(repo.showAppOpenCalls, 0);
        },
      );

      test('never over another full-screen ad', () async {
        await returningUser();
        repo.appOpenReady = true;
        repo.displaying = true;
        await manager.showOnColdStart();
        expect(repo.showAppOpenCalls, 0);
      });

      test('a failed show is not counted as shown', () async {
        await returningUser();
        repo.appOpenReady = true;
        repo.showAppOpenResult = false;
        await manager.showOnColdStart();
        expect(
          storage.get<int>(box, AppConstants.appOpenAdLastShownKey),
          isNull,
        );
      });
    });

    group('returning to the app', () {
      Future<void> away(Duration d) async {
        manager.didChangeAppLifecycleState(AppLifecycleState.paused);
        clock = clock.add(d);
        manager.didChangeAppLifecycleState(AppLifecycleState.resumed);
        await Future<void>.delayed(Duration.zero);
      }

      setUp(() async {
        await returningUser();
        await manager.showOnColdStart(); // settles the cold start (no ad)
        repo.appOpenReady = true;
      });

      test('after a long absence the ad shows, without waiting', () async {
        await away(const Duration(minutes: 30));
        expect(repo.showAppOpenCalls, 1);
        expect(repo.lastWaitUntilClosed, isFalse);
      });

      test(
        'a quick trip out (camera, permission, call) never shows one',
        () async {
          await away(const Duration(minutes: 2));
          expect(repo.showAppOpenCalls, 0);
        },
      );

      test('respects the cooldown', () async {
        await storage.put(
          box,
          AppConstants.appOpenAdLastShownKey,
          clock.millisecondsSinceEpoch,
        );
        await away(const Duration(minutes: 30));
        expect(repo.showAppOpenCalls, 0);
      });

      test('not ready: nothing shown, one is queued for next time', () async {
        repo.appOpenReady = false;
        repo.showAppOpenResult = false;
        final before = repo.preloadAppOpenCalls;
        await away(const Duration(minutes: 30));
        expect(repo.preloadAppOpenCalls, before + 1);
      });

      test('the ad\'s own pause/resume is not "leaving the app"', () async {
        repo.displaying = true;
        manager.didChangeAppLifecycleState(AppLifecycleState.paused);
        repo.displaying = false;
        clock = clock.add(const Duration(hours: 1));
        manager.didChangeAppLifecycleState(AppLifecycleState.resumed);
        await Future<void>.delayed(Duration.zero);
        expect(repo.showAppOpenCalls, 0);
      });
    });

    test('a resume before the cold start has settled shows nothing', () async {
      await returningUser();
      repo.appOpenReady = true;
      manager.didChangeAppLifecycleState(AppLifecycleState.paused);
      clock = clock.add(const Duration(hours: 1));
      manager.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await Future<void>.delayed(Duration.zero);
      expect(repo.showAppOpenCalls, 0);
    });
  });

  group('SnapAdPlan', () {
    test('draws three distinct prayers out of five', () {
      final plan = SnapAdPlan.draw('2026-11-04', Random(1));
      expect(plan.picked.length, 3);
      expect(SnapAdPlan.prayers.toSet().containsAll(plan.picked), isTrue);
    });

    test('no prayer is favoured: every one gets picked over many days', () {
      final counts = {for (final p in SnapAdPlan.prayers) p: 0};
      final random = Random(42);
      for (var d = 0; d < 1000; d++) {
        for (final p in SnapAdPlan.draw('d$d', random).picked) {
          counts[p] = counts[p]! + 1;
        }
      }
      // Expected 600 each (3 of 5); allow a wide band.
      for (final c in counts.values) {
        expect(c, inInclusiveRange(520, 680));
      }
    });

    test('a pick is due once, until it has been shown', () {
      var plan = const SnapAdPlan(day: 'd', picked: {'fajr', 'asr', 'isha'});
      expect(plan.isDue('fajr'), isTrue);
      expect(plan.isDue('dhuhr'), isFalse);
      plan = plan.markShown('fajr');
      expect(plan.isDue('fajr'), isFalse);
      expect(plan.isDue('asr'), isTrue);
    });

    test('survives a save and load, and rejects garbage', () {
      final plan = SnapAdPlan.draw('d', Random(3)).markShown('fajr');
      final back = SnapAdPlan.fromJson(plan.toJson())!;
      expect(back.picked, plan.picked);
      expect(back.shown, {'fajr'});
      expect(SnapAdPlan.fromJson('x'), isNull);
      expect(SnapAdPlan.fromJson({'day': 1}), isNull);
    });
  });

  group('InterstitialAdService', () {
    late InterstitialAdService service;

    InterstitialAdService make({int seed = 1}) {
      final c = makeContainer();
      final p = Provider(
        (ref) =>
            InterstitialAdService(ref, random: Random(seed), now: () => clock),
      );
      return c.read(p);
    }

    setUp(() {
      repo.interstitialReady = true;
      service = make();
    });

    group('Home "See All"', () {
      test('shows when an ad is ready', () async {
        await service.maybeShow(InterstitialPlacement.homeSeeAll);
        expect(repo.showInterstitialCalls, 1);
      });

      test('nothing ready: just carries on', () async {
        repo.interstitialReady = false;
        await service.maybeShow(InterstitialPlacement.homeSeeAll);
        expect(repo.showInterstitialCalls, 0);
      });

      test('never within 3 minutes of another full-screen ad', () async {
        repo.lastEnded = clock.subtract(const Duration(minutes: 2));
        await service.maybeShow(InterstitialPlacement.homeSeeAll);
        expect(repo.showInterstitialCalls, 0);
        repo.lastEnded = clock.subtract(const Duration(minutes: 4));
        await service.maybeShow(InterstitialPlacement.homeSeeAll);
        expect(repo.showInterstitialCalls, 1);
      });

      test('never over an ad that is on screen', () async {
        repo.displaying = true;
        await service.maybeShow(InterstitialPlacement.homeSeeAll);
        expect(repo.showInterstitialCalls, 0);
      });
    });

    group('snap viewing', () {
      Future<List<String>> viewAll(InterstitialAdService s) async {
        final withAd = <String>[];
        for (final prayer in SnapAdPlan.prayers) {
          final before = repo.showInterstitialCalls;
          await s.maybeShow(InterstitialPlacement.snapView, prayer: prayer);
          if (repo.showInterstitialCalls > before) withAd.add(prayer);
          repo.lastEnded = null; // pretend the gap has passed
        }
        return withAd;
      }

      test('exactly three of the five prayers get an ad', () async {
        expect((await viewAll(service)).length, 3);
      });

      test('different days pick different prayers (it is random)', () async {
        final seen = <String>{};
        for (var seed = 0; seed < 12; seed++) {
          clock = DateTime(2026, 11, 4).add(Duration(days: seed));
          storage = InMemoryStorageService();
          final s = make(seed: seed);
          seen.add((await viewAll(s)).join(','));
        }
        expect(seen.length, greaterThan(3));
      });

      test(
        'one ad per prayer: more snaps for the same prayer get none',
        () async {
          final first = await viewAll(service);
          final again = await viewAll(service);
          expect(first.length, 3);
          expect(again, isEmpty);
        },
      );

      test('the day\'s pick is kept: a restart does not re-roll it', () async {
        final first = await viewAll(service);
        repo.showInterstitialCalls = 0;
        final restarted = make(seed: 99);
        final second = await viewAll(restarted);
        expect(second, isEmpty, reason: 'same plan, already used');
        expect(first.length, 3);
      });

      test('a new day draws a fresh plan', () async {
        await viewAll(service);
        clock = clock.add(const Duration(days: 1));
        expect((await viewAll(service)).length, 3);
      });

      test('an ad that was not ready is not used up', () async {
        repo.interstitialReady = false;
        for (final p in SnapAdPlan.prayers) {
          await service.maybeShow(InterstitialPlacement.snapView, prayer: p);
        }
        expect(repo.showInterstitialCalls, 0);
        repo.interstitialReady = true;
        expect((await viewAll(service)).length, 3, reason: 'still all due');
      });

      test('a snap with no known prayer never shows an ad', () async {
        await service.maybeShow(InterstitialPlacement.snapView);
        expect(repo.showInterstitialCalls, 0);
      });

      test('not right after another ad (90 s)', () async {
        repo.lastEnded = clock.subtract(const Duration(seconds: 30));
        for (final p in SnapAdPlan.prayers) {
          await service.maybeShow(InterstitialPlacement.snapView, prayer: p);
        }
        expect(repo.showInterstitialCalls, 0);
      });
    });
  });
}
