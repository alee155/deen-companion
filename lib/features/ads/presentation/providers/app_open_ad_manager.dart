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
