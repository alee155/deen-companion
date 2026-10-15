import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/timezone/device_timezone.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../../core/utils/logger.dart';
import 'auth_providers.dart';
import 'auth_session_provider.dart';

/// Keeps the backend's stored timezone equal to the device's.
///
/// The server decides what "today" is, and validates synced prayer times,
/// in the stored timezone — and accounts default to `UTC`. So this must hold
/// before any `PUT /prayers/times`. It covers accounts created before signup
/// sent a timezone, and users who travel.
class TimezoneSyncService {
  final Ref ref;
  TimezoneSyncService(this.ref);

  String? _confirmed;

  /// True when the backend's timezone is known to match the device's.
  /// False when it couldn't be verified or updated (offline, no signed-in
  /// user, unreadable device zone); callers should skip server-timezone-
  /// dependent work and try again later.
  Future<bool> ensure() async {
    if (!ref.read(authSessionProvider).isAuthenticated) return false;

    final device = await ref.read(deviceTimezoneProvider).iana();
    if (device == null) return false;
    if (device == _confirmed) return true;

    final repo = ref.read(authRepositoryProvider);
    final me = await repo.getCurrentUser();
    if (me case Error(:final failure)) {
      AppLogger.d('Timezone sync: profile unavailable (${failure.message})');
      return false;
    }
    final stored = (me as Success).data.timezone;
    if (stored != device) {
      final updated = await repo.updateTimezone(device);
      if (updated case Error(:final failure)) {
        AppLogger.e('Timezone sync: PATCH failed: ${failure.message}');
        return false;
      }
      AppLogger.i('Timezone updated: ${stored ?? 'none'} -> $device');
    }
    _confirmed = device;
    return true;
  }
}

final timezoneSyncServiceProvider = Provider<TimezoneSyncService>(
  TimezoneSyncService.new,
);
