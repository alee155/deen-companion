import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/dio_client.dart';
import '../../../../core/state/keep_alive_for.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../../core/utils/flow_log.dart';
import '../../../auth/presentation/providers/auth_session_provider.dart';
import '../../../statistics/presentation/providers/statistics_providers.dart';
import '../../../streaks/presentation/providers/streaks_providers.dart';
import '../../data/prayer_logs_remote_datasource.dart';
import '../../data/prayer_logs_repository_impl.dart';
import '../../domain/current_prayer.dart';
import '../../domain/group_member_prayers.dart';
import '../../domain/prayer_log.dart';
import '../../domain/prayer_log_failure.dart';
import '../../domain/prayer_logs_repository.dart';
import '../../../prayer_times/presentation/providers/prayer_times_loader.dart';

final prayerLogsRemoteDataSourceProvider = Provider<PrayerLogsRemoteDataSource>(
  (ref) => PrayerLogsRemoteDataSourceImpl(ref.watch(dioProvider)),
);

final prayerLogsRepositoryProvider = Provider<PrayerLogsRepository>(
  (ref) =>
      PrayerLogsRepositoryImpl(ref.watch(prayerLogsRemoteDataSourceProvider)),
);

/// The home screen's prayer state (`GET /prayers/current`).
///
/// If the server reports no times at all, no location was ever sent: send it
/// (the server then calculates the times) and ask again. Guests have no
/// backend state, so they get an empty one.
class CurrentPrayerNotifier extends AsyncNotifier<CurrentPrayerState> {
  @override
  Future<CurrentPrayerState> build() async {
    if (!ref.watch(authSessionProvider).isAuthenticated) {
      FlowLog.log(_tag, 'GUEST: no prayer log, nothing to ask the server');
      return CurrentPrayerState(now: DateTime.now());
    }
    final repo = ref.read(prayerLogsRepositoryProvider);

    FlowLog.log(_tag, 'ASKING THE SERVER WHICH PRAYER IS OPEN NOW');
    var current = await _unwrap(repo.getCurrent());
    if (current.isNotSynced) {
      FlowLog.log(
        _tag,
        'SERVER HAS NO TIMES FOR THIS ACCOUNT -> SENDING THE LOCATION, then asking again',
      );
      final loaded = await ref.read(prayerTimesLoaderProvider).refresh();
      if (loaded is Success) current = await _unwrap(repo.getCurrent());
    }
    _describe(current);
    return current;
  }

  static const _tag = 'HOME PRAYER';

  static void _describe(CurrentPrayerState s) {
    final c = s.current;
    FlowLog.data(_tag, 'SERVER ANSWER', {
      'open': c == null
          ? 'no prayer open'
          : '${c.prayer.name} (day ${c.date}, ends ${c.endsAt.toUtc().toIso8601String()})',
      'logged': c?.logged,
      'next': s.next == null
          ? 'none'
          : '${s.next!.prayer.name} at ${s.next!.startsAt.toUtc().toIso8601String()}',
      'timesNeverSet': s.isNotSynced,
    });
  }

  /// Re-reads from the server without flashing a loading state.
  Future<void> refresh() async {
    FlowLog.log(_tag, 'REFRESHING THE HOME STATE (no loading flash)');
    state = await AsyncValue.guard(
      () => _unwrap(ref.read(prayerLogsRepositoryProvider).getCurrent()),
    );
    state.whenData(_describe);
  }
}

final currentPrayerProvider =
    AsyncNotifierProvider<CurrentPrayerNotifier, CurrentPrayerState>(
      CurrentPrayerNotifier.new,
    );

/// The caller's logs for one prayer-day (`yyyy-MM-dd`), or — with a null
/// date — for the user's today as the server sees it. Empty is not an error.
final prayerLogsProvider = FutureProvider.autoDispose
    .family<List<PrayerLog>, String?>((ref, date) async {
      if (!ref.watch(authSessionProvider).isAuthenticated) return const [];
      FlowLog.log(
        'CHECKLIST',
        'LOADING LOGS FOR ${date ?? 'TODAY (the server decides the date)'}',
      );
      final logs = await _unwrap(
        ref.read(prayerLogsRepositoryProvider).getLogs(date: date),
      );
      FlowLog.log(
        'CHECKLIST',
        '${logs.length} LOGGED: ${logs.map((l) => l.prayer.name).join(', ')}',
      );
      return logs;
    });

/// The group feed for one prayer-day; a null date means the user's today.
typedef GroupFeedKey = ({String groupId, String? date});

/// Snaps this device has just opened (or found expired), by log id. The feed
/// and live events say a snap is unopened until the next fetch; this keeps the
/// tile right in between, including for logs that came in live.
final snapOutcomesProvider = StateProvider<Map<String, SnapState>>(
  (ref) => const {},
);

/// [feed] with [outcomes] applied to the logs they name.
List<GroupMemberPrayers> applySnapOutcomes(
  List<GroupMemberPrayers> feed,
  Map<String, SnapState> outcomes,
) {
  if (outcomes.isEmpty) return feed;
  PrayerLog apply(PrayerLog l) => switch (outcomes[l.id]) {
    SnapState.opened => l.asViewed(),
    SnapState.expired => l.asExpired(),
    _ => l,
  };
  return [
    for (final m in feed)
      GroupMemberPrayers(
        userId: m.userId,
        name: m.name,
        role: m.role,
        logs: [for (final l in m.logs) apply(l)],
      ),
  ];
}

final groupPrayersProvider = FutureProvider.autoDispose
    .family<List<GroupMemberPrayers>, GroupFeedKey>((ref, key) async {
      // Kept briefly after the group screen closes (so it reopens with the
      // circles and photos already there) and dropped when the account changes.
      final link = keepAliveFor(ref, const Duration(minutes: 15));
      ref.listen(authSessionProvider.select((s) => s.userId), (_, _) {
        link.close();
      });
      if (!ref.watch(authSessionProvider).isAuthenticated) return const [];
      FlowLog.log(
        'GROUP FEED',
        'LOADING group ${key.groupId} for ${key.date ?? 'today'}',
      );
      final feed = await _unwrap(
        ref
            .read(prayerLogsRepositoryProvider)
            .getGroupPrayers(key.groupId, date: key.date),
      );
      FlowLog.data('GROUP FEED', 'MEMBERS', [
        for (final m in feed) '${m.displayName}: ${m.loggedCount}/5',
      ]);
      return feed;
    });

/// A date span (≤ 62 days), `yyyy-MM-dd` both ends.
typedef LogsRange = ({String from, String to});

/// Logs over a span, grouped by prayer-day.
final prayerLogsRangeProvider = FutureProvider.autoDispose
    .family<Map<String, List<PrayerLog>>, LogsRange>((ref, range) async {
      if (!ref.watch(authSessionProvider).isAuthenticated) return const {};
      final logs = await _unwrap(
        ref
            .read(prayerLogsRepositoryProvider)
            .getLogsRange(from: range.from, to: range.to),
      );
      return groupLogsByDate(logs);
    });

Future<T> _unwrap<T>(Future<Result<T>> result) async =>
    (await result).when(success: (d) => d, failure: (f) => throw f);

/// The two write actions, each followed by a refresh so the Log button and
/// the checklist show what the server now holds.
class PrayerLogActions {
  final Ref ref;
  const PrayerLogActions(this.ref);

  /// Logs the open prayer with [imagePath]. On "already logged" the existing
  /// log is on the failure; the state is refreshed in that case too.
  ///
  /// If the server has no times for today yet, the location is sent once (it
  /// then calculates them) and the log is retried once.
  Future<Result<PrayerLog>> log(
    String imagePath, {
    int? viewSeconds,
    List<String>? groupIds,
  }) async {
    const tag = 'LOG PRAYER';
    final repo = ref.read(prayerLogsRepositoryProvider);
    FlowLog.log(
      tag,
      'UPLOADING THE PHOTO (the server decides which prayer this is)',
    );
    var result = await repo.logPrayer(
      imagePath,
      viewSeconds: viewSeconds,
      groupIds: groupIds,
    );
    if (result case Error(:final failure)
        when failure is PrayerLogFailure &&
            failure.code == PrayerLogErrorCode.timesNotSynced) {
      FlowLog.log(
        tag,
        'SERVER SAID PRAYER_TIMES_NOT_SYNCED -> SENDING THE LOCATION, then retrying once',
      );
      final loaded = await ref
          .read(prayerTimesLoaderProvider)
          .refresh(force: true);
      if (loaded is Success) {
        result = await repo.logPrayer(
          imagePath,
          viewSeconds: viewSeconds,
          groupIds: groupIds,
        );
      }
    }
    result.when(
      success: (log) => FlowLog.data(tag, 'LOGGED', {
        'prayer': log.prayer.name,
        'day': log.date,
        'points': log.points,
        'status': log.status.name,
        'hasPhoto': log.snapUrl != null,
        'viewSeconds': log.viewDurationSeconds,
      }),
      failure: (f) => FlowLog.error(
        tag,
        f is PrayerLogFailure ? 'REJECTED (${f.code.name})' : 'FAILED',
        f.message,
      ),
    );
    // A new log, a duplicate, and a closed window all mean the screen's idea
    // of "what is open" is stale.
    await _refresh();
    return result;
  }

  Future<Result<void>> undo(String logId) async {
    FlowLog.log('UNDO', 'DELETING LOG ${FlowLog.mask(logId)}');
    final result = await ref
        .read(prayerLogsRepositoryProvider)
        .deleteLog(logId);
    FlowLog.log(
      'UNDO',
      result.when(
        success: (_) => 'LOG REMOVED (the photo is deleted too)',
        failure: (f) => 'NOT REMOVED: ${f.message}',
      ),
    );
    await _refresh();
    return result;
  }

  /// Sends the snap on [logId] to more groups. No new log: points and streaks
  /// stay as they are, so only the feeds are read again. Safe to repeat.
  Future<Result<PrayerLog>> addGroups(
    String logId,
    List<String> groupIds,
  ) async {
    const tag = 'ADD GROUPS';
    debugPrint(
      '^^^^^^^^^^^^^^^^^^^^ [GROUP PICK] ADDING SNAP $logId TO MORE GROUPS '
      '$groupIds',
    );
    final result = await ref
        .read(prayerLogsRepositoryProvider)
        .addSnapGroups(logId, groupIds);
    result.when(
      success: (log) {
        debugPrint(
          '^^^^^^^^^^^^^^^^^^^^ [GROUP PICK] SNAP NOW IN ${log.groupIds}',
        );
        ref.invalidate(prayerLogsProvider);
        ref.invalidate(groupPrayersProvider);
      },
      failure: (f) {
        FlowLog.error(
          tag,
          f is PrayerLogFailure ? 'REJECTED (${f.code.name})' : 'FAILED',
          f.message,
        );
        // The window closed: the screens' idea of "what is open" is stale.
        if (f is PrayerLogFailure && f.code == PrayerLogErrorCode.snapExpired) {
          ref.invalidate(prayerLogsProvider);
          unawaited(ref.read(currentPrayerProvider.notifier).refresh());
        }
      },
    );
    return result;
  }

  Future<void> _refresh() async {
    FlowLog.log(
      'LOG PRAYER',
      'REFRESHING home state, checklist and group feed',
    );
    ref.invalidate(prayerLogsProvider);
    ref.invalidate(prayerLogsRangeProvider);
    ref.invalidate(groupPrayersProvider);
    // A prayer logged or removed changes every streak it counted toward.
    invalidateStreaks(ref);
    invalidateStatistics(ref);
    await ref.read(currentPrayerProvider.notifier).refresh();
  }
}

final prayerLogActionsProvider = Provider<PrayerLogActions>(
  PrayerLogActions.new,
);
