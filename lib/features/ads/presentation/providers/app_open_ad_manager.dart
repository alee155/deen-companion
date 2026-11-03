import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/di/providers.dart';
import 'ads_providers.dart';

/// Owns the App Open ad: when it may show, and — above all — *when it may no
/// longer show*.
///
/// The old version started the ad and moved on to Home straight away, so an ad
/// that took a few seconds to load popped up over Home. Now the splash screen
/// holds on its own branded screen for a short, fixed budget while the ad that
/// was requested at launch finishes loading:
///
///  * ready within the budget → shown over the splash, Home opens after it's
///    closed;
///  * not ready in time → Home opens, and this launch gets no ad. It is never
///    shown late, only kept for a later return to the app.
///
/// To keep it from being a nuisance it also stays quiet for a 4 hour cooldown,
/// on the very first launch, and on a launch where a consent or tracking
/// prompt was already put in front of the user.
class AppOpenAdManager with WidgetsBindingObserver {
  final Ref _ref;
  final DateTime Function() _now;

  AppOpenAdManager(this._ref, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  /// How long the splash may wait for the ad on a cold start.
  static const coldStartBudget = Duration(milliseconds: 1500);

  /// Least time between two App Open ads.
  static const cooldown = Duration(hours: 4);

  /// Coming back sooner than this is a phone call, the camera, a permission
  /// sheet or a quick glance — never an ad.
  static const minAwayForResumeAd = Duration(minutes: 10);

  DateTime? _backgroundedAt;
  bool _started = false;
  bool _coldStartSettled = false;

  /// Begins watching app lifecycle changes and requests the first ad. Call
  /// once from `bootstrap.dart`. The request waits (inside the repository) for
  /// the ads config and consent, and never blocks the first frame.
  void start() {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    unawaited(_ref.read(adsRepositoryProvider).preloadAppOpenAd());
  }

  /// Called by the splash screen and awaited: shows the ad if it is ready
  /// within [budget], otherwise returns so Home can open. Never throws.
  Future<void> showOnColdStart({Duration budget = coldStartBudget}) async {
    try {
      await _showOnColdStart(budget);
    } catch (error) {
      debugPrint('[Ads] [AppOpenManager] cold start ad skipped: $error');
    } finally {
      _coldStartSettled = true;
    }
  }

  Future<void> _showOnColdStart(Duration budget) async {
    if (!_hasCompletedFirstRun()) return;
    if (_onCooldown()) return;

    final repository = _ref.read(adsRepositoryProvider);
    var ready = repository.isAppOpenAdReady;
    if (!ready) {
      ready = await repository.preloadAppOpenAd().timeout(
        budget,
        onTimeout: () => false,
      );
    }
    if (!ready) {
      debugPrint(
        '[Ads] [AppOpenManager] not ready in time — no ad this launch',
      );
      return;
    }
    if (repository.consentDialogShownThisLaunch) return;
    if (repository.isDisplayingFullScreenAd) return;

    final shown = await repository.showAppOpenAdIfAvailable(
      waitUntilClosed: true,
    );
    if (shown) await _markShown();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final repository = _ref.read(adsRepositoryProvider);

    if (state == AppLifecycleState.paused) {
      // The ad's own screen can make the app report `paused`; that is not the
      // user leaving.
      if (!repository.isDisplayingFullScreenAd) _backgroundedAt = _now();
      return;
    }

    if (state == AppLifecycleState.resumed) {
      unawaited(_maybeShowOnResume());
      unawaited(_ref.read(adsConfigStoreProvider).refreshIfStale());
    }
  }

  Future<void> _maybeShowOnResume() async {
    final left = _backgroundedAt;
    _backgroundedAt = null;
    if (left == null || !_coldStartSettled) return;
    if (_now().difference(left) < minAwayForResumeAd) return;
    if (!_hasCompletedFirstRun() || _onCooldown()) return;

    final repository = _ref.read(adsRepositoryProvider);
    if (repository.isDisplayingFullScreenAd) return;

    // Ready now or not at all: a returning user is never made to wait.
    final shown = await repository.showAppOpenAdIfAvailable();
    if (shown) {
      await _markShown();
    } else {
      unawaited(repository.preloadAppOpenAd());
    }
  }

  bool _onCooldown() {
    final last = _ref
        .read(localStorageServiceProvider)
        .get<int>(
          AppConstants.settingsBoxName,
          AppConstants.appOpenAdLastShownKey,
        );
    if (last == null) return false;
    final at = DateTime.fromMillisecondsSinceEpoch(last);
    return _now().difference(at) < cooldown;
  }

  Future<void> _markShown() async {
    try {
      await _ref
          .read(localStorageServiceProvider)
          .put(
            AppConstants.settingsBoxName,
            AppConstants.appOpenAdLastShownKey,
            _now().millisecondsSinceEpoch,
          );
    } catch (error) {
      debugPrint(
        '[Ads] [AppOpenManager] could not save the shown time: $error',
      );
    }
  }

  /// A brand-new user reaches the app before seeing any ad.
  bool _hasCompletedFirstRun() =>
      _ref
          .read(localStorageServiceProvider)
          .get<bool>(
            AppConstants.settingsBoxName,
            AppConstants.authGateSeenKey,
          ) ??
      false;

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
