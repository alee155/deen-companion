import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../../../core/utils/logger.dart';
import '../../domain/entities/banner_ad_handle.dart';
import '../../domain/repositories/ads_repository.dart';
import '../constants/ads_config.dart';
import '../datasources/app_open_ad_datasource.dart';
import '../datasources/banner_ad_datasource.dart';
import '../datasources/interstitial_ad_datasource.dart';
import '../datasources/mobile_ads_initializer.dart';

class AdsRepositoryImpl implements AdsRepository {
  final MobileAdsInitializer _initializer;
  final BannerAdDataSource _bannerDataSource;
  final InterstitialAdDataSource _interstitialDataSource;
  final AppOpenAdDataSource _appOpenDataSource;

  AdsRepositoryImpl({
    required MobileAdsInitializer initializer,
    required BannerAdDataSource bannerDataSource,
    required InterstitialAdDataSource interstitialDataSource,
    required AppOpenAdDataSource appOpenDataSource,
  }) : _initializer = initializer,
       _bannerDataSource = bannerDataSource,
       _interstitialDataSource = interstitialDataSource,
       _appOpenDataSource = appOpenDataSource;

  // ---------------------------------------------------------------------
  // Interstitial state
  // ---------------------------------------------------------------------
  InterstitialAd? _interstitialAd;
  bool _isLoadingInterstitial = false;
  bool _isShowingInterstitialAd = false;

  // ---------------------------------------------------------------------
  // App open state
  // ---------------------------------------------------------------------
  AppOpenAd? _appOpenAd;
  DateTime? _appOpenLoadedAt;
  bool _isLoadingAppOpenAd = false;
  bool _isShowingAppOpenAd = false;

  /// Google's own guidance: discard an unshown app open ad after roughly
  /// 4 hours rather than showing stale creative.
  static const _appOpenMaxAge = Duration(hours: 4);

  // ---------------------------------------------------------------------
  // Initialization gate
  // ---------------------------------------------------------------------
  // THE FIX: previously, `bootstrap.dart` kicked off SDK initialization
  // (via `adsInitializationProvider`) and the App Open preload (via
  // `AppOpenAdManager.start()`) as two independent fire-and-forget calls,
  // and any `BannerAdWidget` on screen loaded a banner the moment it
  // mounted — none of these waited for `MobileAds.instance.initialize()`
  // to actually finish first. Requesting an ad before the SDK finishes
  // initializing is a real, well-documented cause of ads silently never
  // loading. Every load path below now funnels through
  // [_ensureInitialized], so no matter what order the app happens to call
  // things in, the SDK is always ready before the first ad request goes out.
  Completer<void>? _initCompleter;

  Future<void> _ensureInitialized() {
    final existing = _initCompleter;
    if (existing != null) return existing.future;

    final completer = Completer<void>();
    _initCompleter = completer;

    debugPrint('[Ads] Initializing Mobile Ads SDK…');
    _initializer
        .initialize()
        .then((_) {
          debugPrint('[Ads] Mobile Ads SDK initialized ✅');
          completer.complete();
        })
        .catchError((Object error, StackTrace stackTrace) {
          debugPrint('[Ads] Mobile Ads SDK initialization threw: $error');
          AppLogger.e('Mobile Ads SDK initialization threw', error, stackTrace);
          // Complete anyway — a stuck Completer would permanently wedge
          // every future ad request behind a load that will never finish.
          completer.complete();
        });

    return completer.future;
  }

  @override
  Future<void> initialize() {
    if (!AdsConfig.adsEnabled) {
      debugPrint('[Ads] initialize() skipped — AdsConfig.adsEnabled is false');
      return Future.value();
    }
    return _ensureInitialized();
  }

  // ---------------------------------------------------------------------
  // Banner
  // ---------------------------------------------------------------------

  @override
  Future<BannerAdHandle?> loadBanner({required double width}) async {
    if (!AdsConfig.adsEnabled) {
      debugPrint('[Ads] loadBanner() skipped — ads disabled');
      return null;
    }
    await _ensureInitialized();
    debugPrint('[Ads] Banner: requesting ad (width=$width)…');
    final handle = await _bannerDataSource.load(width: width);
    debugPrint(
      handle == null
          ? '[Ads] Banner: load returned null (failed — see error above)'
          : '[Ads] Banner: loaded ✅ (size=${handle.size.width}x${handle.size.height})',
    );
    return handle;
  }

  // ---------------------------------------------------------------------
  // Interstitial
  // ---------------------------------------------------------------------

  @override
  bool get isInterstitialReady => _interstitialAd != null;

  @override
  Future<void> preloadInterstitial() async {
    if (!AdsConfig.adsEnabled) {
      debugPrint('[Ads] preloadInterstitial() skipped — ads disabled');
      return;
    }
    // Guards duplicate loads: a load already in flight, or an ad already
    // sitting ready and unused, both make a fresh load pointless.
    if (_isLoadingInterstitial || isInterstitialReady) {
      debugPrint(
        '[Ads] Interstitial: preload skipped (loading=$_isLoadingInterstitial, '
        'ready=$isInterstitialReady)',
      );
      return;
    }

    await _ensureInitialized();
    _isLoadingInterstitial = true;
    debugPrint('[Ads] Interstitial: requesting ad…');
    final ad = await _interstitialDataSource.load();
    _isLoadingInterstitial = false;

    if (ad == null) {
      debugPrint(
        '[Ads] Interstitial: load returned null (failed — see error above)',
      );
      return;
    }
    debugPrint('[Ads] Interstitial: loaded ✅');

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (_) {
        debugPrint('[Ads] Interstitial: shown');
        _isShowingInterstitialAd = true;
      },
      onAdDismissedFullScreenContent: (ad) {
        debugPrint('[Ads] Interstitial: dismissed — refilling');
        _isShowingInterstitialAd = false;
        ad.dispose();
        _interstitialAd = null;
        // Refill immediately in the background so the *next* due click
        // already has an ad waiting instead of starting a load from zero.
        unawaited(preloadInterstitial());
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('[Ads] Interstitial: failed to show: $error');
        AppLogger.e('Interstitial failed to show: $error');
        _isShowingInterstitialAd = false;
        ad.dispose();
        _interstitialAd = null;
        unawaited(preloadInterstitial());
      },
    );

    _interstitialAd = ad;
  }

  @override
  void showInterstitial({required AdFlowComplete onComplete}) {
    if (!AdsConfig.adsEnabled) {
      debugPrint('[Ads] showInterstitial() skipped — ads disabled');
      onComplete();
      return;
    }

    // Never stack interstitials, and never make a second call double-fire
    // the completion callback for a show already in progress.
    if (_isShowingInterstitialAd) {
      debugPrint('[Ads] Interstitial: already showing one — skipping');
      onComplete();
      return;
    }

    final ad = _interstitialAd;
    if (ad == null) {
      // Nothing ready — proceed immediately rather than blocking
      // navigation on a network round trip, and queue a load for next
      // time this placement comes due.
      debugPrint('[Ads] Interstitial: none ready — continuing without an ad');
      unawaited(preloadInterstitial());
      onComplete();
      return;
    }

    debugPrint('[Ads] Interstitial: showing…');
    var completed = false;
    void complete() {
      if (completed) return;
      completed = true;
      onComplete();
    }

    // Wrap the ad's own callback so completion fires exactly once,
    // regardless of whether it came from dismissal or a show failure —
    // both are already handled above, this just guarantees the caller's
    // continuation always runs.
    final previous = ad.fullScreenContentCallback;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: previous?.onAdShowedFullScreenContent,
      onAdDismissedFullScreenContent: (ad) {
        previous?.onAdDismissedFullScreenContent?.call(ad);
        complete();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        previous?.onAdFailedToShowFullScreenContent?.call(ad, error);
        complete();
      },
    );

    ad.show();
  }

  // ---------------------------------------------------------------------
  // App Open
  // ---------------------------------------------------------------------

  @override
  bool get isDisplayingFullScreenAd =>
      _isShowingInterstitialAd || _isShowingAppOpenAd;

  @override
  bool get isAppOpenAdReady {
    if (_appOpenAd == null || _appOpenLoadedAt == null) return false;
    final expired =
        DateTime.now().difference(_appOpenLoadedAt!) > _appOpenMaxAge;
    if (expired) {
      // Stale ad — drop it now so the next preload actually runs instead
      // of being skipped by the "already have one" guard below.
      debugPrint('[Ads] App Open: loaded ad expired (>4h old) — discarding');
      _appOpenAd?.dispose();
      _appOpenAd = null;
      _appOpenLoadedAt = null;
      return false;
    }
    return true;
  }

  @override
  Future<void> preloadAppOpenAd() async {
    if (!AdsConfig.adsEnabled) {
      debugPrint('[Ads] preloadAppOpenAd() skipped — ads disabled');
      return;
    }
    if (_isLoadingAppOpenAd || isAppOpenAdReady) {
      debugPrint(
        '[Ads] App Open: preload skipped (loading=$_isLoadingAppOpenAd, '
        'ready=$isAppOpenAdReady)',
      );
      return;
    }

    await _ensureInitialized();
    _isLoadingAppOpenAd = true;
    debugPrint('[Ads] App Open: requesting ad…');
    final ad = await _appOpenDataSource.load();
    _isLoadingAppOpenAd = false;

    if (ad == null) {
      debugPrint(
        '[Ads] App Open: load returned null (failed — see error above)',
      );
      return;
    }
    debugPrint('[Ads] App Open: loaded ✅');

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (_) {
        debugPrint('[Ads] App Open: shown');
        _isShowingAppOpenAd = true;
      },
      onAdDismissedFullScreenContent: (ad) {
        debugPrint('[Ads] App Open: dismissed — refilling');
        _isShowingAppOpenAd = false;
        ad.dispose();
        _appOpenAd = null;
        _appOpenLoadedAt = null;
        unawaited(preloadAppOpenAd());
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('[Ads] App Open: failed to show: $error');
        AppLogger.e('App open ad failed to show: $error');
        _isShowingAppOpenAd = false;
        ad.dispose();
        _appOpenAd = null;
        _appOpenLoadedAt = null;
        unawaited(preloadAppOpenAd());
      },
    );

    _appOpenAd = ad;
    _appOpenLoadedAt = DateTime.now();
  }

  @override
  Future<bool> showAppOpenAdIfAvailable() async {
    if (!AdsConfig.adsEnabled) {
      debugPrint('[Ads] showAppOpenAdIfAvailable() skipped — ads disabled');
      return false;
    }

    // Guards: don't stack on top of an interstitial, don't double-show,
    // don't show an expired ad. Every one of these is "return false now",
    // never "wait and try again" — a resume event is not the moment to
    // introduce a loading delay.
    if (isDisplayingFullScreenAd || !isAppOpenAdReady) {
      debugPrint(
        '[Ads] App Open: not shown (displayingFullScreenAd='
        '$isDisplayingFullScreenAd, ready=$isAppOpenAdReady)',
      );
      return false;
    }

    final ad = _appOpenAd;
    if (ad == null) return false;

    debugPrint('[Ads] App Open: showing…');
    ad.show();
    return true;
  }

  @override
  void dispose() {
    debugPrint('[Ads] Repository disposing — releasing loaded ads');
    _interstitialAd?.dispose();
    _interstitialAd = null;
    _appOpenAd?.dispose();
    _appOpenAd = null;
  }
}
