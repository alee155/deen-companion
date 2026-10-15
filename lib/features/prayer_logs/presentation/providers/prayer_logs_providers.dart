import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/dio_client.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../auth/presentation/providers/auth_session_provider.dart';
import '../../data/prayer_logs_remote_datasource.dart';
import '../../data/prayer_logs_repository_impl.dart';
import '../../domain/current_prayer.dart';
import '../../domain/group_member_prayers.dart';
import '../../domain/prayer_log.dart';
import '../../domain/prayer_logs_repository.dart';
import 'prayer_times_sync_service.dart';

final prayerLogsRemoteDataSourceProvider = Provider<PrayerLogsRemoteDataSource>(
  (ref) => PrayerLogsRemoteDataSourceImpl(ref.watch(dioProvider)),
);

final prayerLogsRepositoryProvider = Provider<PrayerLogsRepository>(
  (ref) =>
      PrayerLogsRepositoryImpl(ref.watch(prayerLogsRemoteDataSourceProvider)),
);

/// The home screen's prayer state (`GET /prayers/current`).
///
/// If the server reports no times at all, they were never synced: sync them
/// once and ask again. Guests have no backend state, so they get an empty one.
class CurrentPrayerNotifier extends AsyncNotifier<CurrentPrayerState> {
  @override
  Future<CurrentPrayerState> build() async {
    if (!ref.watch(authSessionProvider).isAuthenticated) {
      return CurrentPrayerState(now: DateTime.now());
    }
    final repo = ref.read(prayerLogsRepositoryProvider);

    var current = await _unwrap(repo.getCurrent());
    if (current.isNotSynced) {
      final synced = await ref.read(prayerTimesSyncServiceProvider).sync();
      if (synced > 0) current = await _unwrap(repo.getCurrent());
    }
    return current;
  }

  /// Re-reads from the server without flashing a loading state.
  Future<void> refresh() async {
    state = await AsyncValue.guard(
      () => _unwrap(ref.read(prayerLogsRepositoryProvider).getCurrent()),
    );
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
      return _unwrap(
        ref.read(prayerLogsRepositoryProvider).getLogs(date: date),
      );
    });

/// The group feed for one prayer-day; a null date means the user's today.
typedef GroupFeedKey = ({String groupId, String? date});

final groupPrayersProvider = FutureProvider.autoDispose
    .family<List<GroupMemberPrayers>, GroupFeedKey>((ref, key) async {
      if (!ref.watch(authSessionProvider).isAuthenticated) return const [];
      return _unwrap(
        ref
            .read(prayerLogsRepositoryProvider)
            .getGroupPrayers(key.groupId, date: key.date),
      );
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
  Future<Result<PrayerLog>> log(String imagePath) async {
    final result = await ref
        .read(prayerLogsRepositoryProvider)
        .logPrayer(imagePath);
    // A new log, a duplicate, and a closed window all mean the screen's idea
    // of "what is open" is stale.
    await _refresh();
    return result;
  }

  Future<Result<void>> undo(String logId) async {
    final result = await ref
        .read(prayerLogsRepositoryProvider)
        .deleteLog(logId);
    await _refresh();
    return result;
  }

  Future<void> _refresh() async {
    ref.invalidate(prayerLogsProvider);
    ref.invalidate(prayerLogsRangeProvider);
    ref.invalidate(groupPrayersProvider);
    await ref.read(currentPrayerProvider.notifier).refresh();
  }
}

final prayerLogActionsProvider = Provider<PrayerLogActions>(
  PrayerLogActions.new,
);
