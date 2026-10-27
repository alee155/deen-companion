import 'package:flutter/foundation.dart';

import '../constants/app_constants.dart';
import '../utils/logger.dart';
import 'local_storage_service.dart';
import 'token_storage.dart';

/// Drops sign-in tokens left behind by a previous install.
///
/// On iOS the Keychain survives uninstalling an app, while the app's own
/// storage does not. A reinstall would otherwise find a token for a session
/// whose profile data is gone, and look signed in with nothing to show. The
/// local marker only exists once this install has run, so its absence means a
/// first launch and any stored token belongs to an earlier install.
///
/// iOS only: Android's encrypted storage is removed with the app, so there is
/// nothing to clean up (and an update must never sign anyone out).
class FreshInstallGuard {
  static const _markerKey = 'install_marker';

  final LocalStorageService storage;
  final TokenStorage tokens;
  final TargetPlatform platform;

  FreshInstallGuard({
    required this.storage,
    required this.tokens,
    TargetPlatform? platform,
  }) : platform = platform ?? defaultTargetPlatform;

  Future<void> run() async {
    if (platform != TargetPlatform.iOS) return;
    try {
      final seen = storage.get<bool>(AppConstants.settingsBoxName, _markerKey);
      if (seen == true) return;
      await tokens.clear();
      await storage.put(AppConstants.settingsBoxName, _markerKey, true);
    } catch (error, stackTrace) {
      // Never block start-up over housekeeping.
      AppLogger.e('Fresh-install check failed', error, stackTrace);
    }
  }
}
