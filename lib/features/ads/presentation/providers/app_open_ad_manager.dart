import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/di/providers.dart';
import '../../data/constants/ads_config.dart';
import '../../domain/repositories/ads_repository.dart';
import 'ads_providers.dart';

/// Owns the entire App Open ad lifecycle: warms an ad up in the
/// background, watches for genuine "returned to the app from elsewhere"
/// transitions, and shows an ad only when that's actually appropriate.
///
/// Modelled after [PrayerReminderService] (`prayer_reminders` feature): a
/// small `Ref`-holding service, exposed through a single provider, rather
/// than a StateNotifier — there's no UI state here for a widget to watch,
/// just a background process reacting to app lifecycle events.
class AppOpenAdManager with WidgetsBindingObserver {
  final Ref _ref;
  AppOpenAdManager(this._ref);

  /// Set on `paused`, cleared once consumed by a `resumed` check. `null`
  /// means "we have no reason to believe the app was ever backgrounded",
  /// which is exactly the state at cold start — so the very first
  /// `resumed` event (which every app gets once, before any `paused` has
  /// happened) never triggers a show here.
  DateTime? _backgroundedAt;

  bool _started = false;

  /// Begins observing app lifecycle changes and warms up the first ad.
  /// Call once, from `bootstrap.dart`, after the provider container exists.
  void start() {
    if (_started) return;
    if (!AdsConfig.adsEnabled) {
      debugPrint('[Ads] [AppOpenManager] start() skipped — ads disabled');
      return;
    }
    _started = true;
    debugPrint('[Ads] [AppOpenManager] started — observing app lifecycle');
    WidgetsBinding.instance.addObserver(this);
    // Fire-and-forget: the first frame must never wait on an ad network
    // call, cold start or not.
    unawaited(_ref.read(adsRepositoryProvider).preloadAppOpenAd());
  }

  /// Shows the App Open ad for a genuine **cold start** — called once by
  /// the splash screen, right when it determines this is a *returning*
  /// user heading straight to Home (onboarding and permissions already
  /// completed), not a first-time install still going through onboarding.
  ///
  /// This is the path [didChangeAppLifecycleState] below can never cover
  /// on its own: that observer only fires on genuine background→
  /// foreground transitions, and a fresh process launch is neither — it's
  /// the very first lifecycle event the app gets, with no prior `paused`
  /// to compare against, which is exactly what [_maybeShowOnResume]
  /// deliberately ignores. Cold start needs its own explicit trigger.
  ///
  /// Fire-and-forget by design, same as every other ad path in this
  /// feature: never awaited by the caller, so a slow network or an
  /// unavailable ad can never delay navigation to Home.
  void maybeShowOnColdStart() {
    if (!AdsConfig.adsEnabled) {
      debugPrint('[Ads] [AppOpenManager] cold start show skipped — ads disabled');
      return;
    }
    unawaited(_showOnColdStart());
  }

  Future<void> _showOnColdStart() async {
    final repository = _ref.read(adsRepositoryProvider);

    // Guards against the (unlikely but possible) case where an
    // interstitial or another app open ad is already up by the time the
    // splash screen makes this call.
    if (repository.isDisplayingFullScreenAd) {
      debugPrint(
        '[Ads] [AppOpenManager] cold start: another full-screen ad is '
        'already showing — skipping',
      );
      return;
    }

    if (!repository.isAppOpenAdReady) {
      // THE ACTUAL FIX: on a real cold start, the ad realistically never
      // has finished loading yet at this exact instant — SDK init plus
      // the ad network round trip routinely takes 1-4 seconds, and this
      // method gets called right as Home is about to render. Instead of
      // checking readiness once and giving up (which is what silently
      // ate every cold-start impression before), wait on the exact same
      // preload that was already kicked off in start() — no duplicate
      // request, just the result of the one already in flight.
      debugPrint(
        '[Ads] [AppOpenManager] cold start: ad not ready yet — awaiting '
        'the in-flight preload…',
      );
      final loaded = await repository.preloadAppOpenAd();
      debugPrint('[Ads] [AppOpenManager] cold start: preload settled, loaded=$loaded');
      if (!loaded) return;

      // Re-check: something else (a resume/pause cycle, an interstitial)
      // could have started showing a full-screen ad during the wait.
      if (repository.isDisplayingFullScreenAd) {
        debugPrint(
          '[Ads] [AppOpenManager] cold start: a full-screen ad started '
          'showing while waiting for the preload — skipping',
        );
        return;
      }
    }

    debugPrint('[Ads] [AppOpenManager] cold start: attempting to show');
    final shown = await repository.showAppOpenAdIfAvailable();
    debugPrint(
      '[Ads] [AppOpenManager] cold start showAppOpenAdIfAvailable() -> $shown',
    );
    if (!shown) {
      // Nothing was ready yet (the preload kicked off in `start()` may
      // still be in flight) — don't retry-loop waiting for it now, just
      // make sure one is queued for the next resume.
      unawaited(repository.preloadAppOpenAd());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    debugPrint('[Ads] [AppOpenManager] lifecycle state changed: $state');
    final repository = _ref.read(adsRepositoryProvider);

    if (state == AppLifecycleState.paused) {
      // If we're the ones currently showing a full-screen ad, the ad's
      // own activity transition can itself emit a `paused`/`resumed`
      // pair — that is not the user leaving the app, so it must not be
      // recorded as a "real" backgrounding.
      if (!repository.isDisplayingFullScreenAd) {
        debugPrint('[Ads] [AppOpenManager] recorded a real backgrounding');
        _backgroundedAt = DateTime.now();
      } else {
        debugPrint(
          '[Ads] [AppOpenManager] paused while showing a full-screen ad — '
          'not counted as a real backgrounding',
        );
      }
      return;
    }

    if (state == AppLifecycleState.resumed) {
      unawaited(_maybeShowOnResume(repository));
    }
  }

  Future<void> _maybeShowOnResume(AdsRepository repository) async {
    final wasBackgrounded = _backgroundedAt != null;
    _backgroundedAt = null;
    if (!wasBackgrounded) {
      debugPrint(
        '[Ads] [AppOpenManager] resumed without a prior real backgrounding '
        '(e.g. cold start) — not showing',
      );
      return;
    }

    // Never interrupt, or immediately follow, another full-screen ad —
    // covers both "an interstitial is on screen right now" and "the
    // resume event was actually the app open ad's own show transition".
    if (repository.isDisplayingFullScreenAd) {
      debugPrint(
        '[Ads] [AppOpenManager] resumed while a full-screen ad is already '
        'showing — not showing another',
      );
      return;
    }

    // Don't show a first-run user an ad before they've even reached the
    // app: only start showing App Open ads once onboarding and the
    // permissions flow have both been completed at least once.
    if (!_hasCompletedFirstRun()) {
      debugPrint(
        '[Ads] [AppOpenManager] onboarding/permission flow not completed '
        'yet — not showing',
      );
      return;
    }

    debugPrint('[Ads] [AppOpenManager] genuine resume — attempting to show');
    final shown = await repository.showAppOpenAdIfAvailable();
    debugPrint('[Ads] [AppOpenManager] showAppOpenAdIfAvailable() -> $shown');
    if (!shown) {
      // Nothing was ready — don't leave the user waiting on a load that
      // was never going to finish in time to matter; just queue the next
      // one for the following resume.
      unawaited(repository.preloadAppOpenAd());
    }
  }

  bool _hasCompletedFirstRun() {
    final storage = _ref.read(localStorageServiceProvider);
    final onboardingCompleted =
        storage.get<bool>(
          AppConstants.settingsBoxName,
          AppConstants.onboardingCompletedKey,
        ) ??
        false;
    final permissionFlowSeen =
        storage.get<bool>(
          AppConstants.settingsBoxName,
          AppConstants.permissionFlowSeenKey,
        ) ??
        false;
    debugPrint(
      '[Ads] [AppOpenManager] onboardingCompleted=$onboardingCompleted '
      'permissionFlowSeen=$permissionFlowSeen',
    );
    return onboardingCompleted && permissionFlowSeen;
  }

  void dispose() {
    if (!_started) return;
    WidgetsBinding.instance.removeObserver(this);
    _started = false;
  }
}

final appOpenAdManagerProvider = Provider<AppOpenAdManager>((ref) {
  final manager = AppOpenAdManager(ref);
  ref.onDispose(manager.dispose);
  return manager;
});
