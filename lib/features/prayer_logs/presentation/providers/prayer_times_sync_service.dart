import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/utils/logger.dart';
import '../../../auth/presentation/providers/auth_session_provider.dart';
import '../../../auth/presentation/providers/timezone_sync_service.dart';
import '../../../prayer_times/presentation/providers/prayer_calculation_settings_provider.dart';
import '../../../prayer_times/presentation/providers/upcoming_prayer_days.dart';
import 'prayer_logs_providers.dart';
import '../../../prayer_times/domain/entities/prayer_times.dart';
import '../../domain/prayer_times_sync_payload.dart';

/// Uploads the next 8 days of prayer windows so the server knows when each
/// prayer is open. Runs for signed-in users on app start, when the
/// calculation method or Asr school changes, and on sign-in.
class PrayerTimesSyncService {
  final Ref ref;
  PrayerTimesSyncService(this.ref);

  /// `PUT /prayers/times` is limited to 20/min; a burst of triggers (e.g.
  /// method then school) collapses into one request.
  static const _debounce = Duration(seconds: 2);

  Timer? _timer;
  bool _running = false;
  bool _rerun = false;

  void schedule() {
    _timer?.cancel();
    _timer = Timer(_debounce, () => unawaited(sync()));
  }

  /// Returns the number of days the server accepted (0 if nothing to do).
  Future<int> sync() async {
    if (!ref.read(authSessionProvider).isAuthenticated) return 0;
    if (_running) {
      _rerun = true;
      return 0;
    }
    _running = true;
    try {
      final count = await _sync();
      if (_rerun) {
        _rerun = false;
        return await _sync();
      }
      return count;
    } catch (e, st) {
      AppLogger.e('Prayer times sync failed', e, st);
      return 0;
    } finally {
      _running = false;
    }
  }

  Future<int> _sync() async {
    // The server validates dates in the stored timezone, which defaults to
    // UTC — it has to match the device before any times are sent.
    if (!await ref.read(timezoneSyncServiceProvider).ensure()) {
      AppLogger.d('Prayer times sync skipped: timezone not confirmed');
      return 0;
    }
    final now = DateTime.now();
    final loaded = await loadUpcomingPrayerDays(
      ref,
      now: now,
      windowDays: PrayerTimesSyncPayload.maxDays - 1,
    );
    if (loaded.error != null) {
      AppLogger.d('Prayer times sync skipped: ${loaded.error}');
      return 0;
    }

    var days = PrayerTimesSyncPayload.build(loaded.days, now);
    _logReceived(now, loaded.days, days);
    if (days.isEmpty) return 0;

    final remote = ref.read(prayerLogsRemoteDataSourceProvider);
    try {
      _logSent(days);
      await remote.syncTimes(days);
    } on ServerException catch (e) {
      AppLogger.i(
        'PrayerSync <- server rejected: status=${e.statusCode} '
        'code=${e.code} message=${e.message}',
      );
      if (!_isDayLocked(e)) rethrow;
      // Today is the day that gets logged, so it is the one that locks. The
      // server applied nothing, so resend without it.
      final todayDate = days.first['date'];
      days = days.where((d) => d['date'] != todayDate).toList();
      if (days.isEmpty) return 0;
      AppLogger.i('PrayerSync: day locked, retrying without $todayDate');
      _logSent(days);
      await remote.syncTimes(days);
    }
    AppLogger.i('PrayerSync <- server accepted ${days.length} days');
    return days.length;
  }

  /// What Aladhan returned (device-local clock times) next to what survived
  /// the checks, so a missing day can be traced.
  void _logReceived(
    DateTime now,
    List<PrayerTimes> received,
    List<Map<String, String>> kept,
  ) {
    final keptDates = {for (final d in kept) d['date']};
    final lines = [
      for (final d in received)
        '  ${keptDates.contains(PrayerTimesSyncPayload.dateOf(d)) ? 'SEND' : 'skip'} '
            '${PrayerTimesSyncPayload.describeReceived(d)}',
    ];
    AppLogger.i(
      'PrayerSync: device now=${now.toIso8601String()} '
      'offset=${now.timeZoneOffset} zone=${now.timeZoneName}\n'
      'PrayerSync -> received from Aladhan (${received.length} days, '
      'local times):\n${lines.join('\n')}',
    );
  }

  void _logSent(List<Map<String, String>> days) {
    AppLogger.i(
      'PrayerSync -> PUT /prayers/times (${days.length} days):\n'
      '${const JsonEncoder.withIndent('  ').convert({'days': days})}',
    );
  }

  static bool _isDayLocked(ServerException e) =>
      e.statusCode == 409 &&
      (e.code == 'PRAYER_DAY_LOCKED' ||
          (e.message ?? '').contains('PRAYER_DAY_LOCKED') ||
          e.code == null);

  void dispose() => _timer?.cancel();
}

final prayerTimesSyncServiceProvider = Provider<PrayerTimesSyncService>((ref) {
  final service = PrayerTimesSyncService(ref);
  ref.listen(prayerCalculationSettingsProvider, (_, _) => service.schedule());
  ref.listen(authSessionProvider, (prev, next) {
    if (next.isAuthenticated && prev?.userId != next.userId) {
      service.schedule();
    }
  });
  ref.onDispose(service.dispose);
  return service;
});
