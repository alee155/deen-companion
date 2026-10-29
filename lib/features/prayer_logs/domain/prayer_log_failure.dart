import '../../../core/error/failures.dart';
import '../../prayer_times/domain/entities/prayer_times.dart';
import 'prayer_log.dart';

/// Backend error codes the app reacts to specifically. Anything else is
/// [other] — the message still reaches the user.
enum PrayerLogErrorCode {
  dayLocked('PRAYER_DAY_LOCKED'),
  timesNotSynced('PRAYER_TIMES_NOT_SYNCED'),
  noActiveWindow('NO_ACTIVE_PRAYER_WINDOW'),
  alreadyLogged('PRAYER_ALREADY_LOGGED'),

  /// Client-detected, or HTTP 413 from the server.
  fileTooLarge('FILE_TOO_LARGE'),

  /// `DELETE` after the window closed (HTTP 400): the record is final.
  undoLocked('UNDO_LOCKED'),

  /// HTTP 403 on the group feed: only members can see it.
  notGroupMember('NOT_GROUP_MEMBER'),

  /// HTTP 410 on `POST /prayers/logs/{id}/view`: this viewer already opened
  /// the snap (it opens once per person).
  snapAlreadyViewed('SNAP_ALREADY_VIEWED'),

  /// HTTP 410 on the same call: the prayer window ended.
  snapExpired('SNAP_EXPIRED'),

  /// HTTP 429: more than 20 calls a minute.
  rateLimited('RATE_LIMITED'),
  other('');

  final String wire;
  const PrayerLogErrorCode(this.wire);

  static PrayerLogErrorCode parse(String? code) => values.firstWhere(
    (c) => c.wire.isNotEmpty && c.wire == code,
    orElse: () => other,
  );
}

/// A server error on a prayer endpoint, keeping the [code] and the optional
/// `data` payload (e.g. `{nextPrayer, startsAt}` for [noActiveWindow], the
/// existing log for [alreadyLogged]).
class PrayerLogFailure extends ServerFailure {
  final PrayerLogErrorCode code;
  final int? statusCode;
  final Map<String, dynamic>? data;

  /// For [PrayerLogErrorCode.alreadyLogged]: the log that already exists.
  final PrayerLog? existingLog;

  /// For [PrayerLogErrorCode.noActiveWindow]: what opens next.
  final PrayerName? nextPrayer;
  final DateTime? nextStartsAt;

  const PrayerLogFailure(
    super.message, {
    this.code = PrayerLogErrorCode.other,
    this.statusCode,
    this.data,
    this.existingLog,
    this.nextPrayer,
    this.nextStartsAt,
  });
}
