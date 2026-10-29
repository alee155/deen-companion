import '../../../core/usecase/usecase.dart';
import 'current_prayer.dart';
import 'group_member_prayers.dart';
import 'prayer_log.dart';

abstract class PrayerLogsRepository {
  /// Largest photo the server accepts (`SNAP_MAX_MB`).
  static const maxPhotoBytes = 5 * 1024 * 1024;

  /// The range the server accepts for `viewDurationSeconds`.
  static const minViewSeconds = 1;
  static const maxViewSeconds = 10;

  /// Logs the prayer that is open right now with [imagePath] as proof. The
  /// server decides which prayer; see `PrayerLogFailure` for the outcomes
  /// (no open window, already logged, not synced, too large).
  ///
  /// [groupIds] limits who sees the snap to those groups; without it the
  /// server shows it in every group the caller belongs to.
  Future<Result<PrayerLog>> logPrayer(
    String imagePath, {
    int? viewSeconds,
    List<String>? groupIds,
  });

  /// Sends the snap on [logId] (yours, already logged) to more groups
  /// (`POST /prayers/logs/{id}/groups`). Repeating it is harmless: groups that
  /// already have the snap are ignored. No new log, no change to points or
  /// streaks. Fails with `snapExpired` once the window has closed. Returns the
  /// log, whose `groupIds` now lists every group that has the snap.
  Future<Result<PrayerLog>> addSnapGroups(String logId, List<String> groupIds);

  /// Opens another member's snap (`POST /prayers/logs/{id}/view`). The link
  /// works once: a second call fails with `snapAlreadyViewed`, and after the
  /// window `snapExpired`. Never retried.
  Future<Result<OpenedSnap>> viewSnap(String logId);

  /// Everyone in a group and what they logged on [date] (null → today).
  /// A non-member gets a failure with `PrayerLogErrorCode.notGroupMember`.
  Future<Result<List<GroupMemberPrayers>>> getGroupPrayers(
    String groupId, {
    String? date,
  });

  /// Undo — allowed only while the prayer's window is open.
  Future<Result<void>> deleteLog(String id);

  Future<Result<CurrentPrayerState>> getCurrent();

  /// Null [date] → the user's today (server-side, profile timezone).
  Future<Result<List<PrayerLog>>> getLogs({String? date});

  Future<Result<List<PrayerLog>>> getLogsRange({
    required String from,
    required String to,
  });
}
