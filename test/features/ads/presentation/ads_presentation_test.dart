import 'package:deen_companion/core/constants/app_constants.dart';
import 'package:deen_companion/core/storage/local_storage_service.dart';
import 'package:deen_companion/features/ads/domain/entities/banner_ad_handle.dart';
import 'package:deen_companion/features/ads/domain/repositories/ads_repository.dart';
import 'package:deen_companion/features/ads/presentation/providers/ads_providers.dart';
import 'package:deen_companion/features/ads/presentation/providers/app_open_ad_manager.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/in_memory_storage_service.dart';

class FakeAdsRepository implements AdsRepository {
  bool interstitialReady = false;
  bool displaying = false;
  bool appOpenReady = false;
  bool preloadAppOpenResult = false;
  bool showAppOpenResult = true;

  int showInterstitialCalls = 0;
  int showAppOpenCalls = 0;
  int preloadAppOpenCalls = 0;
  int preloadInterstitialCalls = 0;
  int initializeCalls = 0;
  bool disposed = false;

  /// When set, [showInterstitial] keeps the completion so tests can simulate
  /// the user dismissing the ad later.
  AdFlowComplete? pendingComplete;
  bool completeImmediately = false;

  @override
  Future<void> initialize() async => initializeCalls++;

  @override
  Future<BannerAdHandle?> loadBanner({required double width}) async => null;

  @override
  bool get isInterstitialReady => interstitialReady;

  @override
  Future<void> preloadInterstitial() async => preloadInterstitialCalls++;

  @override
  void showInterstitial({required AdFlowComplete onComplete}) {
    showInterstitialCalls++;
    if (completeImmediately) {
      onComplete();
    } else {
      pendingComplete = onComplete;
    }
  }

  @override
  bool get isDisplayingFullScreenAd => displaying;

  @override
  bool get isAppOpenAdReady => appOpenReady;

  @override
  Future<bool> preloadAppOpenAd() async {
    preloadAppOpenCalls++;
    if (preloadAppOpenResult) appOpenReady = true;
    return preloadAppOpenResult;
  }

  @override
  Future<bool> showAppOpenAdIfAvailable() async {
    showAppOpenCalls++;
    return showAppOpenResult;
  }

  @override
  void dispose() => disposed = true;
}

ProviderContainer makeContainer(
  FakeAdsRepository repo,
  InMemoryStorageService storage,
) {
  final c = ProviderContainer(
    overrides: [
      adsRepositoryProvider.overrideWithValue(repo),
      localStorageServiceProvider.overrideWithValue(storage),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeAdsRepository repo;
  late InMemoryStorageService storage;
  late ProviderContainer container;

  setUp(() {
    repo = FakeAdsRepository();
    storage = InMemoryStorageService();
    container = makeContainer(repo, storage);
  });

  group('adsInitializationProvider', () {
    test('initializes the repository and loads no interstitial', () async {
      await container.read(adsInitializationProvider.future);
      expect(repo.initializeCalls, 1);
      expect(repo.preloadInterstitialCalls, 0);
    });
  });

  group('AppOpenAdManager', () {
    const box = AppConstants.settingsBoxName;
    late AppOpenAdManager manager;

    setUp(() {
      manager = container.read(appOpenAdManagerProvider);
    });
    tearDown(() => manager.dispose());

    Future<void> settle() => Future<void>.delayed(Duration.zero);

    test('start preloads once and is idempotent', () {
      manager.start();
      manager.start();
      expect(repo.preloadAppOpenCalls, 1);
    });

    test('start is skipped when the ad was already shown once', () async {
      await storage.put(box, AppConstants.appOpenAdShownKey, true);
      manager.start();
      expect(repo.preloadAppOpenCalls, 0);
    });

    group('cold start', () {
      test('ready ad is shown and the shown flag is persisted', () async {
        repo.appOpenReady = true;
        manager.start();
        manager.maybeShowOnColdStart();
        await settle();
        expect(repo.showAppOpenCalls, 1);
        expect(storage.get<bool>(box, AppConstants.appOpenAdShownKey), isTrue);
      });

      test('waits for in-flight preload when not ready, then shows', () async {
        repo.preloadAppOpenResult = true;
        manager.start();
        manager.maybeShowOnColdStart();
        await settle();
        expect(repo.showAppOpenCalls, 1);
      });

      test('failed preload means nothing is shown and flag not set', () async {
        repo.preloadAppOpenResult = false;
        manager.maybeShowOnColdStart();
        await settle();
        expect(repo.showAppOpenCalls, 0);
        expect(storage.get<bool>(box, AppConstants.appOpenAdShownKey), isNull);
      });

      test('does nothing while another full-screen ad is on screen', () async {
        repo.appOpenReady = true;
        repo.displaying = true;
        manager.maybeShowOnColdStart();
        await settle();
        expect(repo.showAppOpenCalls, 0);
      });

      test('only attempts once per process', () async {
        repo.appOpenReady = true;
        repo.showAppOpenResult = false;
        manager.maybeShowOnColdStart();
        manager.maybeShowOnColdStart();
        await settle();
        expect(repo.showAppOpenCalls, 1);
      });

      test(
        'show returning false queues a preload and does not persist',
        () async {
          repo.appOpenReady = true;
          repo.showAppOpenResult = false;
          manager.maybeShowOnColdStart();
          await settle();
          expect(repo.preloadAppOpenCalls, 1);
          expect(
            storage.get<bool>(box, AppConstants.appOpenAdShownKey),
            isNull,
          );
        },
      );

      test('skipped entirely when already shown once', () async {
        await storage.put(box, AppConstants.appOpenAdShownKey, true);
        repo.appOpenReady = true;
        manager.maybeShowOnColdStart();
        await settle();
        expect(repo.showAppOpenCalls, 0);
      });
    });

    group('resume', () {
      Future<void> pauseThenResume() async {
        manager.didChangeAppLifecycleState(AppLifecycleState.paused);
        manager.didChangeAppLifecycleState(AppLifecycleState.resumed);
        await settle();
      }

      test('resume without a prior pause never shows (cold start)', () async {
        await storage.put(box, AppConstants.authGateSeenKey, true);
        manager.didChangeAppLifecycleState(AppLifecycleState.resumed);
        await settle();
        expect(repo.showAppOpenCalls, 0);
      });

      test('pause + resume shows once the auth gate is passed', () async {
        await storage.put(box, AppConstants.authGateSeenKey, true);
        manager.start();
        await pauseThenResume();
        expect(repo.showAppOpenCalls, 1);
        expect(storage.get<bool>(box, AppConstants.appOpenAdShownKey), isTrue);
      });

      test('first-run users (gate not passed) are never shown an ad', () async {
        await pauseThenResume();
        expect(repo.showAppOpenCalls, 0);
      });

      test(
        'pause while our own full-screen ad is up is not a backgrounding',
        () async {
          await storage.put(box, AppConstants.authGateSeenKey, true);
          repo.displaying = true;
          manager.didChangeAppLifecycleState(AppLifecycleState.paused);
          repo.displaying = false;
          manager.didChangeAppLifecycleState(AppLifecycleState.resumed);
          await settle();
          expect(repo.showAppOpenCalls, 0);
        },
      );

      test('resume while another ad is displayed does not show', () async {
        await storage.put(box, AppConstants.authGateSeenKey, true);
        manager.didChangeAppLifecycleState(AppLifecycleState.paused);
        repo.displaying = true;
        manager.didChangeAppLifecycleState(AppLifecycleState.resumed);
        await settle();
        expect(repo.showAppOpenCalls, 0);
      });

      test('when nothing could be shown a fresh ad is queued', () async {
        await storage.put(box, AppConstants.authGateSeenKey, true);
        repo.showAppOpenResult = false;
        await pauseThenResume();
        expect(repo.preloadAppOpenCalls, 1);
        expect(storage.get<bool>(box, AppConstants.appOpenAdShownKey), isNull);
      });

      test(
        'backgrounding is consumed: a second resume does not re-show',
        () async {
          await storage.put(box, AppConstants.authGateSeenKey, true);
          repo.showAppOpenResult = false;
          await pauseThenResume();
          manager.didChangeAppLifecycleState(AppLifecycleState.resumed);
          await settle();
          expect(repo.showAppOpenCalls, 1);
        },
      );

      test('already shown once: resume never shows again', () async {
        await storage.put(box, AppConstants.authGateSeenKey, true);
        await storage.put(box, AppConstants.appOpenAdShownKey, true);
        await pauseThenResume();
        expect(repo.showAppOpenCalls, 0);
      });
    });
  });
}
