import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../utils/logger.dart';

/// Thin wrapper around Firebase Remote Config, kept behind an interface
/// for the same reason `LocationService` and `AppInfoService` are: call
/// sites (right now, just `AdUnitResolver`) depend on this abstraction,
/// not the Firebase SDK directly.
///
/// This is a general-purpose Remote Config gateway, not an ads-only
/// concept — it lives in `core/`, not `features/ads/`, so any future
/// feature that wants a remotely-toggleable flag reuses this same
/// service instead of standing up its own Firebase wiring.
///
/// Split into two deliberately different-speed operations — this is the
/// piece that makes App Open ads (and everything else reading these
/// flags) available as soon as possible after app launch:
///   • [ensureReady] is fast and local — no network call. It activates
///     whatever config was already fetched and cached during a *previous*
///     session, so [getBool] returns real values immediately.
///   • [refresh] is the slow, network-bound fetch of *fresh* values from
///     the Firebase backend. It's never on the critical path for the
///     first ad of a session — callers kick it off in the background and
///     let the *next* ad load (after this one is shown/dismissed, or
///     expires) pick up whatever it found.
abstract class RemoteConfigService {
  /// Local-only: sets defaults and activates the last cached config, if
  /// any. Safe to call more than once — a call made while one is already
  /// in flight awaits that same call rather than repeating the work.
  Future<void> ensureReady();

  /// Fetches and activates the latest config from the Firebase backend.
  /// Should be called after [ensureReady], but never needs to be awaited
  /// by anything that just wants to read a value now — [getBool] already
  /// reflects whatever [ensureReady] activated, and will reflect this
  /// fetch's result once it completes.
  Future<void> refresh();

  /// Reads a Boolean parameter. Returns `defaultValue` if [ensureReady]
  /// hasn't finished yet, or if the key doesn't exist — never throws.
  bool getBool(String key, {bool defaultValue = false});
}

class FirebaseRemoteConfigService implements RemoteConfigService {
  FirebaseRemoteConfigService();

  FirebaseRemoteConfig? _remoteConfig;
  Completer<void>? _readyCompleter;

  @override
  Future<void> ensureReady() {
    final existing = _readyCompleter;
    if (existing != null) {
      debugPrint('[RemoteConfig] ensureReady() already in flight — awaiting it');
      return existing.future;
    }

    final completer = Completer<void>();
    _readyCompleter = completer;

    _ensureReadyInternal()
        .then((_) => completer.complete())
        .catchError((Object error, StackTrace stackTrace) {
          debugPrint('[RemoteConfig] ensureReady() failed: $error');
          AppLogger.e('Remote Config ensureReady() failed', error, stackTrace);
          // Complete anyway — every getBool() call falls back to its
          // provided default, so a Remote Config outage degrades
          // gracefully instead of wedging every future ad-unit
          // resolution behind a load that never finishes.
          completer.complete();
        });

    return completer.future;
  }

  Future<void> _ensureReadyInternal() async {
    // Defensive guard, not the primary initialization path: Firebase is
    // expected to already be set up in bootstrap.dart before this is ever
    // called. This just makes the service safe to use standalone (e.g. in
    // a test) without silently double-initializing Firebase if it isn't.
    if (Firebase.apps.isEmpty) {
      debugPrint('[RemoteConfig] Firebase not yet initialized — initializing now');
      await Firebase.initializeApp();
    }

    final remoteConfig = FirebaseRemoteConfig.instance;
    _remoteConfig = remoteConfig;

    await remoteConfig.setConfigSettings(
      RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: kDebugMode
            ? Duration.zero
            : const Duration(hours: 1),
      ),
    );

    // Defaults matter: this is what getBool() returns if this is a
    // genuinely first-ever launch, with nothing cached from a previous
    // session yet. false here means "test ads in debug / disabled in
    // release" until the first successful fetch — safe by default, never
    // real ads by accident.
    await remoteConfig.setDefaults(const {
      'AppOpen': false,
      'Banner': false,
      'Interstitial': false,
    });

    // THE KEY CALL for fast App Open ads: activate() alone (no fetch())
    // is a local, no-network operation — it just makes whatever was
    // already fetched and cached during a *previous* session active for
    // reads right now. On a returning user's second-or-later launch,
    // this means getBool() already reflects real Remote Config values
    // before any network call has even started this session.
    final activatedFromCache = await remoteConfig.activate();
    debugPrint(
      '[RemoteConfig] ensureReady(): activated cached config = '
      '$activatedFromCache',
    );
    debugPrint(
      '[RemoteConfig] cached values — '
      'Banner=${remoteConfig.getBool('Banner')} '
      'Interstitial=${remoteConfig.getBool('Interstitial')} '
      'AppOpen=${remoteConfig.getBool('AppOpen')}',
    );
  }

  @override
  Future<void> refresh() async {
    if (_remoteConfig == null) {
      debugPrint('[RemoteConfig] refresh() called before ensureReady() — running it first');
      await ensureReady();
    }
    final remoteConfig = _remoteConfig;
    if (remoteConfig == null) return;

    try {
      debugPrint('[RemoteConfig] fetching fresh config…');
      final activated = await remoteConfig.fetchAndActivate();
      debugPrint('[RemoteConfig] fetchAndActivate() -> activated=$activated');
      debugPrint(
        '[RemoteConfig] fresh values — '
        'Banner=${remoteConfig.getBool('Banner')} '
        'Interstitial=${remoteConfig.getBool('Interstitial')} '
        'AppOpen=${remoteConfig.getBool('AppOpen')}',
      );
    } catch (error, stackTrace) {
      debugPrint('[RemoteConfig] refresh() failed: $error');
      AppLogger.e('Remote Config refresh failed', error, stackTrace);
      // Never rethrow — a failed background refresh just means the app
      // keeps using whatever ensureReady() already activated.
    }
  }

  @override
  bool getBool(String key, {bool defaultValue = false}) {
    final remoteConfig = _remoteConfig;
    if (remoteConfig == null) {
      // ensureReady() hasn't resolved yet — safe default, never blocks.
      return defaultValue;
    }
    try {
      return remoteConfig.getBool(key);
    } catch (error) {
      debugPrint('[RemoteConfig] getBool($key) failed: $error — using default');
      return defaultValue;
    }
  }
}

final remoteConfigServiceProvider = Provider<RemoteConfigService>((ref) {
  return FirebaseRemoteConfigService();
});
