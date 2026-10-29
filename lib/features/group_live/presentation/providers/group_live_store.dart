import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/utils/flow_log.dart';
import '../../../auth/presentation/providers/auth_session_provider.dart';
import '../../../auth/presentation/providers/session_keep_alive.dart';
import '../../../groups/presentation/providers/groups_providers.dart';
import '../../../prayer_logs/domain/group_member_prayers.dart';
import '../../../prayer_logs/domain/prayer_log.dart';
import '../../../prayer_logs/presentation/providers/prayer_logs_providers.dart';
import '../../../streaks/domain/entities/group_streaks.dart';
import '../../../streaks/presentation/providers/streaks_providers.dart';
import '../../data/group_summary_remote_datasource.dart';
import '../../domain/group_summary.dart';
import '../../domain/realtime_event.dart';
import 'realtime_providers.dart';

final groupSummaryRemoteDataSourceProvider =
    Provider<GroupSummaryRemoteDataSource>(
      (ref) => GroupSummaryRemoteDataSourceImpl(ref.watch(dioProvider)),
    );

/// Why a group left the user's screen on its own.
enum GroupGone { deleted, removed }

/// A group's numbers and member rows, kept current by summary fetches and live
/// events. Both write here and the screen only reads, so ordering and
/// de-duplication live in one place.
class GroupLiveState extends Equatable {
  /// Null until the first summary arrives.
  final GroupSummary? summary;

  /// Set when the summary could not be loaded.
  final Object? error;

  /// The UTC instant the held numbers are good for: the last summary's `Date`,
  /// or the last applied event's `emittedAt`. Older events are ignored.
  final DateTime? lastAppliedAt;
  final String? etag;

  /// Logs added/removed by live events since the feed was last fetched, laid
  /// over the REST feed by [overlayFeed]. Bounded.
  final Map<String, LiveLog> addedLogs;
  final Set<String> removedLogIds;
  final GroupGone? gone;

  const GroupLiveState({
    this.summary,
    this.error,
    this.lastAppliedAt,
    this.etag,
    this.addedLogs = const {},
    this.removedLogIds = const {},
    this.gone,
  });

  GroupLiveState copyWith({
    GroupSummary? summary,
    Object? error,
    bool clearError = false,
    DateTime? lastAppliedAt,
    String? etag,
    Map<String, LiveLog>? addedLogs,
    Set<String>? removedLogIds,
    GroupGone? gone,
  }) => GroupLiveState(
    summary: summary ?? this.summary,
    error: clearError ? null : (error ?? this.error),
    lastAppliedAt: lastAppliedAt ?? this.lastAppliedAt,
    etag: etag ?? this.etag,
    addedLogs: addedLogs ?? this.addedLogs,
    removedLogIds: removedLogIds ?? this.removedLogIds,
    gone: gone ?? this.gone,
  );

  @override
  List<Object?> get props => [
    summary,
    error,
    lastAppliedAt,
    etag,
    addedLogs,
    removedLogIds,
    gone,
  ];
}

const _overlayCap = 200;

class GroupLiveNotifier
    extends AutoDisposeFamilyNotifier<GroupLiveState, String> {
  bool _alive = true;
  bool _fetching = false;
  bool _fetchAgain = false;

  /// The newest event applied while a summary request was in flight: if it is
  /// newer than the answer, the answer is older than what is on screen.
  DateTime? _appliedDuringFetch;

  @override
  GroupLiveState build(String groupId) {
    _alive = true;
    keepAliveForSession(ref, streaksKeepAlive);

    // A prayer logged or removed here, or a changed goal: the numbers moved.
    ref.listen(streaksRevisionProvider, (_, _) => unawaited(refresh()));

    final service = ref.read(realtimeServiceProvider);
    service?.watch(groupId);
    ref.onDispose(() {
      _alive = false;
      service?.unwatch(groupId);
    });

    Future.microtask(refresh);
    return const GroupLiveState();
  }

  /// Fetches the summary (with `If-None-Match`) and replaces the numbers and
  /// member rows with it. Overlapping calls fold into one follow-up request.
  Future<void> refresh() async {
    if (!_alive) return;
    if (_fetching) {
      _fetchAgain = true;
      return;
    }
    _fetching = true;
    try {
      do {
        _fetchAgain = false;
        await _fetchOnce();
      } while (_fetchAgain && _alive);
    } finally {
      _fetching = false;
    }
  }

  Future<void> _fetchOnce() async {
    if (!ref.read(authSessionProvider).isAuthenticated) return;
    _appliedDuringFetch = null;
    try {
      final response = await ref
          .read(groupSummaryRemoteDataSourceProvider)
          .fetch(arg, etag: state.etag);
      if (!_alive) return;
      final serverTime = response.serverTime;
      FlowLog.log(
        'REALTIME',
        'SUMMARY ${response is SummaryFresh ? 'FRESH' : 'NOT MODIFIED (304)'} '
            'for group ${FlowLog.mask(arg)}, server time $serverTime',
      );
      final newest = _newer(state.lastAppliedAt, serverTime);
      switch (response) {
        case SummaryFresh(:final summary, :final etag):
          state = state.copyWith(
            summary: summary,
            etag: etag,
            clearError: true,
            lastAppliedAt: newest,
          );
        case SummaryNotModified():
          state = state.copyWith(clearError: true, lastAppliedAt: newest);
      }
      // An event newer than this answer was applied while it was on its way:
      // the answer is older than the screen, ask again.
      final during = _appliedDuringFetch;
      if (during != null && serverTime != null && during.isAfter(serverTime)) {
        _fetchAgain = true;
      }
    } on ServerException catch (e) {
      if (!_alive) return;
      if (e.statusCode == 403 || e.statusCode == 404) {
        // Not a member any more (removed, or the group is gone).
        _markGone(GroupGone.removed);
      } else {
        _fail(e);
      }
    } on Exception catch (e) {
      if (!_alive) return;
      _fail(e);
    }
  }

  void _fail(Object error) {
    FlowLog.log('REALTIME', 'SUMMARY NOT LOADED: $error');
    // Numbers already on screen stay; the error only matters with none.
    state = state.copyWith(error: error);
  }

  static DateTime? _newer(DateTime? a, DateTime? b) {
    if (a == null) return b;
    if (b == null) return a;
    return b.isAfter(a) ? b : a;
  }

  void _markGone(GroupGone why) {
    if (state.gone != null) return;
    state = state.copyWith(gone: why);
    ref.read(realtimeServiceProvider)?.forget(arg);
    ref.read(myGroupsProvider.notifier).dropLocally(arg);
  }

  /// Runs one live event through the pipeline: stale check, apply, remember
  /// when. ([RealtimeService] has already dropped repeats by `eventId`.)
  void apply(RealtimeEvent event) {
    if (!_alive) return;
    final last = state.lastAppliedAt;
    // Older than what we hold: it describes a state we are already past.
    if (last != null && event.emittedAt.isBefore(last)) {
      FlowLog.log(
        'REALTIME',
        'EVENT DROPPED as stale: emitted ${event.emittedAt.toIso8601String()} '
            'is older than ${last.toIso8601String()}',
      );
      return;
    }
    FlowLog.log(
      'REALTIME',
      'APPLYING ${event.runtimeType} to group ${FlowLog.mask(arg)}',
    );

    // Only an event that arrives while a request is already on its way can
    // make that answer stale; the request this event starts itself cannot.
    final requestInFlight = _fetching;
    switch (event) {
      case PrayerLoggedEvent():
        _applyLogged(event);
      case PrayerDeletedEvent():
        _applyDeleted(event);
      case GroupChangedEvent(:final reason):
        if (reason == GroupChangeReason.groupDeleted) {
          _markGone(GroupGone.deleted);
        } else if (reason != GroupChangeReason.groupUpdated) {
          // Members, roles or the goal changed: the summary has the new rows.
          unawaited(refresh());
        }
    }
    state = state.copyWith(lastAppliedAt: event.emittedAt);
    if (requestInFlight) _appliedDuringFetch = event.emittedAt;
  }

  void _applyLogged(PrayerLoggedEvent e) {
    // A log already in the list (the user logged it and got it from REST) is
    // not added twice; only the numbers apply.
    final added = {...state.addedLogs};
    // The same log id again is the owner adding this group to a snap they had
    // already sent elsewhere: an update to that log, not a new prayer. The
    // later event is the one that carries the snap.
    final known = added[e.log.id];
    if (known == null || (e.log.hasSnap && !known.hasSnap)) {
      added[e.log.id] = e.log;
    }
    state = state.copyWith(
      addedLogs: _capped(added),
      removedLogIds: {...state.removedLogIds}..remove(e.log.id),
    );
    _applyNumbers(e.group, e.member);
  }

  void _applyDeleted(PrayerDeletedEvent e) {
    final removed = {...state.removedLogIds, e.logId};
    state = state.copyWith(
      addedLogs: {...state.addedLogs}..remove(e.logId),
      removedLogIds: removed.length > _overlayCap
          ? removed.skip(removed.length - _overlayCap).toSet()
          : removed,
    );
    _applyNumbers(e.group, e.member);
  }

  Map<String, LiveLog> _capped(Map<String, LiveLog> m) =>
      m.length <= _overlayCap
      ? m
      : Map.fromEntries(m.entries.skip(m.length - _overlayCap));

  void _applyNumbers(GroupNumbers group, MemberSnapshot member) {
    final summary = state.summary;
    if (summary == null) return; // the first summary will carry them
    if (summary.member(member.userId) == null) {
      // Someone we have no row for (just joined): the summary has them.
      unawaited(refresh());
      return;
    }
    state = state.copyWith(
      summary: summary.applying(group: group, member: member),
    );
  }
}

final groupLiveProvider = NotifierProvider.autoDispose
    .family<GroupLiveNotifier, GroupLiveState, String>(GroupLiveNotifier.new);

/// The streak board for the group screen: the live summary's rows (in
/// leaderboard order), or — only when the summary could not be loaded — the
/// plain streak board. Null while it loads.
final liveGroupBoardProvider = Provider.autoDispose
    .family<GroupStreakBoard?, String>((ref, groupId) {
      final live = ref.watch(groupLiveProvider(groupId));
      final summary = live.summary;
      if (summary != null) return summary.toBoard();
      if (live.error == null) return null;
      return ref.watch(groupStreakBoardProvider(groupId)).valueOrNull;
    });

/// Today's feed with live events laid over it: logs added or removed since
/// the REST feed was fetched. Null while the feed itself has not loaded.
final liveGroupFeedProvider = Provider.autoDispose
    .family<List<GroupMemberPrayers>?, String>((ref, groupId) {
      final feed = ref
          .watch(groupPrayersProvider((groupId: groupId, date: null)))
          .valueOrNull;
      if (feed == null) return null;
      final live = ref.watch(groupLiveProvider(groupId));
      return applySnapOutcomes(
        overlayFeed(
          feed,
          added: live.addedLogs,
          removed: live.removedLogIds,
          today: _localToday(),
        ),
        ref.watch(snapOutcomesProvider),
      );
    });

String _localToday() {
  final n = DateTime.now();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${n.year}-${two(n.month)}-${two(n.day)}';
}

/// [feed] with [added] logs inserted and [removed] ones dropped, by log id.
///
/// The feed is one prayer-day. An added log belongs to it only when its own
/// date matches the day the feed shows (read off the feed's logs, or [today]
/// when it has none); a log from another day still counted in the numbers but
/// has no row here.
List<GroupMemberPrayers> overlayFeed(
  List<GroupMemberPrayers> feed, {
  required Map<String, LiveLog> added,
  required Set<String> removed,
  required String today,
}) {
  if (added.isEmpty && removed.isEmpty) return feed;
  String? feedDate;
  for (final m in feed) {
    if (m.logs.isNotEmpty) {
      feedDate = m.logs.first.date;
      break;
    }
  }
  final day = feedDate ?? today;
  return [
    for (final m in feed)
      GroupMemberPrayers(
        userId: m.userId,
        name: m.name,
        role: m.role,
        logs: _mergeLogs(m, added, removed, day),
      ),
  ];
}

List<PrayerLog> _mergeLogs(
  GroupMemberPrayers m,
  Map<String, LiveLog> added,
  Set<String> removed,
  String day,
) {
  final logs = [
    for (final l in m.logs)
      if (!removed.contains(l.id))
        // A live update says this group now has the snap.
        if (added[l.id] case final a?
            when a.userId == m.userId && a.hasSnap && !l.hasSnap)
          l.withSnapSent()
        else
          l,
  ];
  final have = {for (final l in logs) l.id};
  for (final a in added.values) {
    if (a.userId != m.userId || a.date != day || have.contains(a.id)) continue;
    // One circle per prayer: a live log for a prayer the feed already shows
    // under another id would double it.
    if (logs.any((l) => l.prayer == a.prayer)) continue;
    logs.add(a.toPrayerLog());
  }
  logs.sort((a, b) => a.prayer.index.compareTo(b.prayer.index));
  return logs;
}
