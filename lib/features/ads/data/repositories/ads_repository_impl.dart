import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../../../core/utils/logger.dart';
import '../../domain/entities/banner_ad_handle.dart';
import '../../domain/repositories/ads_repository.dart';
import '../datasources/app_open_ad_datasource.dart';
import '../datasources/banner_ad_datasource.dart';
import '../datasources/interstitial_ad_datasource.dart';
import '../datasources/mobile_ads_initializer.dart';
import '../services/ad_unit_resolver.dart';
import '../services/ads_config_store.dart';
import '../services/ads_consent.dart';

class AdsRepositoryImpl implements AdsRepository {
  final MobileAdsInitializer _initializer;
  final AdUnitResolver _adUnitResolver;
  final AdsConfigStore _config;
  final AdsConsent _consent;
  final BannerAdDataSource _bannerDataSource;
  final InterstitialAdDataSource _interstitialDataSource;
  final AppOpenAdDataSource _appOpenDataSource;
  final DateTime Function() _now;

  AdsRepositoryImpl({
    required MobileAdsInitializer initializer,
    required AdUnitResolver adUnitResolver,
    required AdsConfigStore config,
    required AdsConsent consent,
    required BannerAdDataSource bannerDataSource,
    required InterstitialAdDataSource interstitialDataSource,
    required AppOpenAdDataSource appOpenDataSource,
    DateTime Function()? now,
  }) : _initializer = initializer,
       _adUnitResolver = adUnitResolver,
       _config = config,
       _consent = consent,
       _bannerDataSource = bannerDataSource,
       _interstitialDataSource = interstitialDataSource,
       _appOpenDataSource = appOpenDataSource,
       _now = now ?? DateTime.now;

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
  bool _isShowingAppOpenAd = false;
  Completer<void>? _appOpenClosed;

  /// Google's own guidance: discard an unshown app open ad after roughly
  /// 4 hours rather than showing stale creative.
  static const _appOpenMaxAge = Duration(hours: 4);

  DateTime? _lastFullScreenAdEndedAt;
  bool _consentDialogShown = false;

  @override
  DateTime? get lastFullScreenAdEndedAt => _lastFullScreenAdEndedAt;

  @override
  bool get consentDialogShownThisLaunch => _consentDialogShown;

  // ---------------------------------------------------------------------
  // Gate: config → consent → SDK
  // ---------------------------------------------------------------------
  // Every load path goes through [_canServe]. Nothing is requested before
  // the ads service has answered (or its saved answer was read), and nothing
  // before the user's consent choices are settled — so no ad request can
  // fire before either.
  Future<bool>? _sdkReady;

  Future<bool> _canServe() async {
    await _config.ready;
    if (!_config.current.adsEnabled) return false;
    return _sdkReady ??= _prepareSdk();
  }

  Future<bool> _prepareSdk() async {
    try {
      final consent = await _consent.gather();
      _consentDialogShown = consent.dialogShown;
      if (!consent.canRequestAds) {
        debugPrint('[Ads] consent does not allow ad requests — no ads');
        return false;
      }
      await _initializer.initialize();
      debugPrint('[Ads] Mobile Ads SDK initialized ✅');
      return true;
    } catch (error, stackTrace) {
      debugPrint('[Ads] Initialization threw: $error');
      AppLogger.e('Ads initialization threw', error, stackTrace);
      // Keep going: a wedged gate would block every later ad request.
      return true;
    }
  }

  @override
  Future<void> initialize() async {
    if (!await _canServe()) return;
    unawaited(preloadInterstitial());
  }

  // ---------------------------------------------------------------------
  // Banner
  // ---------------------------------------------------------------------

  @override
  Future<BannerAdHandle?> loadBanner({required double width}) async {
    if (!await _canServe()) {
      debugPrint('[Ads] loadBanner() skipped — ads off');
      return null;
    }

    final resolved = _adUnitResolver.banner();
    if (!resolved.shouldLoad) {
      debugPrint('[Ads] Banner: skipped — resolved to disabled');
      return null;
    }

    debugPrint('[Ads] Banner: requesting ad (width=$width)…');
    final handle = await _bannerDataSource.load(
      width: width,
      adUnitId: resolved.adUnitId!,
    );
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
    if (_isLoadingInterstitial || isInterstitialReady) {
      debugPrint(
        '[Ads] Interstitial: preload skipped (loading=$_isLoadingInterstitial, '
        'ready=$isInterstitialReady)',
      );
      return;
    }
    _isLoadingInterstitial = true;
    try {
      if (!await _canServe()) return;

      final resolved = _adUnitResolver.interstitial();
      if (!resolved.shouldLoad) {
        debugPrint('[Ads] Interstitial: preload skipped — disabled');
        return;
      }

      debugPrint('[Ads] Interstitial: requesting ad…');
      final ad = await _interstitialDataSource.load(
        adUnitId: resolved.adUnitId!,
      );
      if (ad == null) {
        debugPrint('[Ads] Interstitial: load returned null (failed)');
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
          _lastFullScreenAdEndedAt = _now();
          ad.dispose();
          _interstitialAd = null;
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
    } finally {
      _isLoadingInterstitial = false;
    }
  }

  @override
  bool showInterstitial({required AdFlowComplete onComplete}) {
    // Never stack interstitials, and never make a second call double-fire
    // the completion callback for a show already in progress.
    if (_isShowingInterstitialAd || _isShowingAppOpenAd) {
      debugPrint('[Ads] Interstitial: a full-screen ad is up — skipping');
      onComplete();
      return false;
    }

    final ad = _interstitialAd;
    if (ad == null) {
      // Nothing ready — proceed immediately rather than blocking the user
      // on a network round trip, and queue a load for next time.
      debugPrint('[Ads] Interstitial: none ready — continuing without an ad');
      unawaited(preloadInterstitial());
      onComplete();
      return false;
    }

    debugPrint('[Ads] Interstitial: showing…');
    var completed = false;
    void complete() {
      if (completed) return;
      completed = true;
      onComplete();
    }

    // Completion fires exactly once, whether the ad was dismissed or failed
    // to show, so the caller's continuation always runs.
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
    return true;
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
    final expired = _now().difference(_appOpenLoadedAt!) > _appOpenMaxAge;
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

  // Shared by every caller of preloadAppOpenAd() while a load is in flight,
  // so the cold-start path can wait on the preload that is already running
  // instead of starting a second request.
  Completer<bool>? _appOpenLoadCompleter;

  @override
  Future<bool> preloadAppOpenAd() async {
    if (isAppOpenAdReady) return true;

    final inFlight = _appOpenLoadCompleter;
    if (inFlight != null) return inFlight.future;

    final completer = Completer<bool>();
    _appOpenLoadCompleter = completer;

    Future<bool> finish(bool loaded) {
      _appOpenLoadCompleter = null;
      completer.complete(loaded);
      return completer.future;
    }

    if (!await _canServe()) return finish(false);

    final resolved = _adUnitResolver.appOpen();
    if (!resolved.shouldLoad) {
      debugPrint('[Ads] App Open: preload skipped — disabled');
      return finish(false);
    }

    debugPrint('[Ads] App Open: requesting ad…');
    final ad = await _appOpenDataSource.load(adUnitId: resolved.adUnitId!);
    if (ad == null) {
      debugPrint('[Ads] App Open: load returned null (failed)');
      return finish(false);
    }
    debugPrint('[Ads] App Open: loaded ✅');

    void closed(AppOpenAd ad) {
      _isShowingAppOpenAd = false;
      _lastFullScreenAdEndedAt = _now();
      ad.dispose();
      _appOpenAd = null;
      _appOpenLoadedAt = null;
      final waiting = _appOpenClosed;
      _appOpenClosed = null;
      if (waiting != null && !waiting.isCompleted) waiting.complete();
    }

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (_) {
        debugPrint('[Ads] App Open: shown');
        _isShowingAppOpenAd = true;
      },
      onAdDismissedFullScreenContent: (ad) {
        debugPrint('[Ads] App Open: dismissed — refilling');
        closed(ad);
        unawaited(preloadAppOpenAd());
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('[Ads] App Open: failed to show: $error');
        AppLogger.e('App open ad failed to show: $error');
        closed(ad);
        unawaited(preloadAppOpenAd());
      },
    );

    _appOpenAd = ad;
    _appOpenLoadedAt = _now();
    return finish(true);
  }

  @override
  Future<bool> showAppOpenAdIfAvailable({bool waitUntilClosed = false}) async {
    // Don't stack on top of another ad, don't show an expired one. Never
    // "wait and try again": a show attempt is not the moment to add a delay.
    if (isDisplayingFullScreenAd || !isAppOpenAdReady) {
      debugPrint(
        '[Ads] App Open: not shown (displayingFullScreenAd='
        '$isDisplayingFullScreenAd, ready=$isAppOpenAdReady)',
      );
      return false;
    }

    final ad = _appOpenAd;
    if (ad == null) return false;

    final closed = waitUntilClosed
        ? (_appOpenClosed = Completer<void>())
        : null;
    debugPrint('[Ads] App Open: showing…');
    ad.show();
    if (closed != null) await closed.future;
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
