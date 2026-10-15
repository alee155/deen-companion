import '../../../core/usecase/usecase.dart';
import 'current_prayer.dart';
import 'group_member_prayers.dart';
import 'prayer_log.dart';

abstract class PrayerLogsRepository {
  /// Largest photo the server accepts (`SNAP_MAX_MB`).
  static const maxPhotoBytes = 5 * 1024 * 1024;

  /// Logs the prayer that is open right now with [imagePath] as proof. The
  /// server decides which prayer; see `PrayerLogFailure` for the outcomes
  /// (no open window, already logged, not synced, too large).
  Future<Result<PrayerLog>> logPrayer(String imagePath);

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
