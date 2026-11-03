import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/di/providers.dart';
import '../../domain/snap_ad_plan.dart';
import 'ads_providers.dart';

/// Where an interstitial can appear.
enum InterstitialPlacement {
  /// A "See All" link on Home.
  homeSeeAll,

  /// Opening a snap someone sent.
  snapView,
}

/// Decides whether an interstitial is appropriate right now, and shows it.
///
/// Every check errs on the side of the user: an ad that is not loaded, that
/// would follow another ad too closely, or that is not due is simply skipped,
/// and the thing the person tapped always goes ahead.
class InterstitialAdService {
  final Ref _ref;
  final Random _random;
  final DateTime Function() _now;

  InterstitialAdService(this._ref, {Random? random, DateTime Function()? now})
    : _random = random ?? Random(),
      _now = now ?? DateTime.now;

  /// Quiet time after the last full-screen ad (any kind) before another.
  static const homeSeeAllGap = Duration(minutes: 3);
  static const snapViewGap = Duration(seconds: 90);

  SnapAdPlan? _plan;

  /// Shows an interstitial if one is due for [placement], and completes once
  /// it's closed — or at once when none is shown. Never throws. For
  /// [InterstitialPlacement.snapView], pass the snap's [prayer]
  /// (`PrayerName.name`).
  Future<void> maybeShow(
    InterstitialPlacement placement, {
    String? prayer,
  }) async {
    try {
      if (!_isDue(placement, prayer)) return;

      final repository = _ref.read(adsRepositoryProvider);
      if (repository.isDisplayingFullScreenAd) return;
      final last = repository.lastFullScreenAdEndedAt;
      final gap = placement == InterstitialPlacement.homeSeeAll
          ? homeSeeAllGap
          : snapViewGap;
      if (last != null && _now().difference(last) < gap) return;

      final closed = Completer<void>();
      final shown = repository.showInterstitial(onComplete: closed.complete);
      if (!shown) return;
      await closed.future;
      await _recordShown(placement, prayer);
    } catch (error) {
      debugPrint('[Ads] interstitial skipped: $error');
    }
  }

  bool _isDue(InterstitialPlacement placement, String? prayer) {
    switch (placement) {
      case InterstitialPlacement.homeSeeAll:
        return true;
      case InterstitialPlacement.snapView:
        if (prayer == null) return false;
        return _todaysPlan().isDue(prayer);
    }
  }

  Future<void> _recordShown(
    InterstitialPlacement placement,
    String? prayer,
  ) async {
    if (placement == InterstitialPlacement.snapView && prayer != null) {
      await _savePlan(_todaysPlan().markShown(prayer));
    }
  }

  /// The plan for today: loaded if one was already drawn, else drawn now.
  SnapAdPlan _todaysPlan() {
    final today = SnapAdPlan.dayKey(_now());
    final held = _plan;
    if (held != null && held.day == today) return held;
    final storage = _ref.read(localStorageServiceProvider);
    try {
      final raw = storage.get<String>(
        AppConstants.settingsBoxName,
        AppConstants.snapAdPlanKey,
      );
      final saved = raw == null ? null : SnapAdPlan.fromJson(jsonDecode(raw));
      if (saved != null && saved.day == today) return _plan = saved;
    } catch (_) {}
    final fresh = SnapAdPlan.draw(today, _random);
    unawaited(_savePlan(fresh));
    return fresh;
  }

  Future<void> _savePlan(SnapAdPlan plan) async {
    _plan = plan;
    try {
      await _ref
          .read(localStorageServiceProvider)
          .put(
            AppConstants.settingsBoxName,
            AppConstants.snapAdPlanKey,
            jsonEncode(plan.toJson()),
          );
    } catch (error) {
      debugPrint('[Ads] could not save the snap ad plan: $error');
    }
  }
}

final interstitialAdServiceProvider = Provider<InterstitialAdService>(
  (ref) => InterstitialAdService(ref),
);
