import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/storage/local_storage_service.dart';
import '../../domain/entities/remote_ads_config.dart';
import '../datasources/ads_config_remote_datasource.dart';

/// Holds the ads config the rest of the feature reads.
///
/// Rules, from the ads service guide:
///  * the saved copy is used straight away; it is refetched only once older
///    than its `ttl_seconds`;
///  * with no saved copy, the app waits (at most the 5 s request timeout) for
///    the first fetch, and shows no ads if that fails;
///  * the config is never guessed: no answer means [RemoteAdsConfig.off].
class AdsConfigStore {
  final AdsConfigRemoteDataSource _remote;
  final LocalStorageService _storage;
  final String _platform;
  final DateTime Function() _now;

  AdsConfigStore({
    required AdsConfigRemoteDataSource remote,
    required LocalStorageService storage,
    required String platform,
    DateTime Function()? now,
  }) : _remote = remote,
       _storage = storage,
       _platform = platform,
       _now = now ?? DateTime.now;

  RemoteAdsConfig _current = RemoteAdsConfig.off;
  DateTime? _fetchedAt;
  String? _etag;
  Future<void>? _loading;
  Future<void>? _refreshing;

  RemoteAdsConfig get current => _current;

  /// Completes once the config is known: from the saved copy, or from the
  /// first fetch when there is none. Never throws.
  Future<void> get ready => _loading ??= _load();

  Future<void> _load() async {
    final cached = _readCache();
    if (cached) {
      if (_isStale) unawaited(_refresh());
      return;
    }
    await _refresh();
  }

  bool get _isStale {
    final at = _fetchedAt;
    if (at == null) return true;
    return _now().difference(at) >= Duration(seconds: _current.ttlSeconds);
  }

  /// Fetches again if the saved config has outlived its TTL (for when the app
  /// returns to the foreground after a long time).
  Future<void> refreshIfStale() async {
    await ready;
    if (_isStale) await _refresh();
  }

  Future<void> _refresh() => _refreshing ??= _fetch().whenComplete(() {
    _refreshing = null;
  });

  Future<void> _fetch() async {
    final result = await _remote.fetch(
      appKey: AppConstants.adsAppKey,
      platform: _platform,
      etag: _etag,
    );
    if (result == null) return;
    if (result.notModified) {
      _fetchedAt = _now();
    } else if (result.config != null) {
      _current = result.config!;
      _fetchedAt = _now();
      _etag = result.etag;
    }
    await _writeCache();
  }

  bool _readCache() {
    try {
      final raw = _storage.get<String>(
        AppConstants.settingsBoxName,
        AppConstants.adsConfigCacheKey,
      );
      if (raw == null) return false;
      final map = jsonDecode(raw) as Map<String, dynamic>;
      _current = RemoteAdsConfig.fromJson(
        Map<String, dynamic>.from(map['config'] as Map),
      );
      _fetchedAt = DateTime.fromMillisecondsSinceEpoch(map['fetchedAt'] as int);
      _etag = map['etag'] as String?;
      return true;
    } catch (error) {
      debugPrint('[Ads] ignoring unreadable saved config: $error');
      return false;
    }
  }

  Future<void> _writeCache() async {
    try {
      await _storage.put(
        AppConstants.settingsBoxName,
        AppConstants.adsConfigCacheKey,
        jsonEncode({
          'config': _current.toJson(),
          'fetchedAt': _fetchedAt?.millisecondsSinceEpoch,
          'etag': _etag,
        }),
      );
    } catch (error) {
      debugPrint('[Ads] could not save the ads config: $error');
    }
  }
}
