import '../../prayer_logs/domain/prayer_log.dart';
import '../../prayer_times/domain/entities/prayer_times.dart';
import 'group_summary.dart';

/// Why a group changed (`group.changed`). The event carries no data, only
/// this; the app refetches what the reason affects.
enum GroupChangeReason {
  memberJoined,
  memberLeft,
  memberRemoved,
  roleChanged,
  ruleChanged,
  groupUpdated,
  groupDeleted,

  /// A reason this app version does not know: treated as "something about the
  /// members changed".
  unknown;

  static GroupChangeReason parse(String? raw) => switch (raw) {
    'member_joined' => memberJoined,
    'member_left' => memberLeft,
    'member_removed' => memberRemoved,
    'role_changed' => roleChanged,
    'rule_changed' => ruleChanged,
    'group_updated' => groupUpdated,
    'group_deleted' => groupDeleted,
    _ => unknown,
  };
}

/// The prayer inside `prayer.logged`.
class LiveLog {
  final String id;
  final String userId;
  final PrayerName prayer;

  /// The logger's own prayer-day (`yyyy-MM-dd`): never converted or parsed as
  /// an instant.
  final String date;
  final int points;
  final DateTime loggedAt;

  /// A snap was sent to this group. The link itself is never broadcast: the
  /// viewer asks for it when they open the snap.
  final bool hasSnap;

  const LiveLog({
    required this.id,
    required this.userId,
    required this.prayer,
    required this.date,
    required this.points,
    required this.loggedAt,
    this.hasSnap = false,
  });

  /// An event does not carry the window or status, so those take neutral
  /// values: it is another member's log (nobody undoes those from here).
  PrayerLog toPrayerLog() => PrayerLog(
    id: id,
    prayer: prayer,
    date: date,
    status: PrayerLogStatus.unknown,
    points: points,
    snapUrl: null,
    hasSnap: hasSnap,
    windowKnown: false,
    windowStartsAt: loggedAt,
    windowEndsAt: loggedAt,
    loggedAt: loggedAt,
  );
}

sealed class RealtimeEvent {
  /// Stable per event: the same event always has the same id.
  final String eventId;

  /// An instant (UTC).
  final DateTime emittedAt;
  final String groupId;

  const RealtimeEvent({
    required this.eventId,
    required this.emittedAt,
    required this.groupId,
  });
}

class PrayerLoggedEvent extends RealtimeEvent {
  final LiveLog log;
  final MemberSnapshot member;
  final GroupNumbers group;

  const PrayerLoggedEvent({
    required super.eventId,
    required super.emittedAt,
    required super.groupId,
    required this.log,
    required this.member,
    required this.group,
  });
}

class PrayerDeletedEvent extends RealtimeEvent {
  final String logId;
  final String userId;
  final MemberSnapshot member;
  final GroupNumbers group;

  const PrayerDeletedEvent({
    required super.eventId,
    required super.emittedAt,
    required super.groupId,
    required this.logId,
    required this.userId,
    required this.member,
    required this.group,
  });
}

class GroupChangedEvent extends RealtimeEvent {
  final GroupChangeReason reason;

  const GroupChangedEvent({
    required super.eventId,
    required super.emittedAt,
    required super.groupId,
    required this.reason,
  });
}

const prayerLoggedEventName = 'prayer.logged';
const prayerDeletedEventName = 'prayer.deleted';
const groupChangedEventName = 'group.changed';

/// Parses a server event, or returns null for a payload that is not in the
/// documented shape (an event the app cannot trust is dropped, never half
/// applied).
RealtimeEvent? parseRealtimeEvent(String name, Object? payload) {
  if (payload is! Map) return null;
  try {
    final j = Map<String, dynamic>.from(payload);
    final eventId = j['eventId'] as String;
    final emittedAt = DateTime.parse(j['emittedAt'] as String).toUtc();
    final groupId = j['groupId'] as String;
    switch (name) {
      case prayerLoggedEventName:
        final l = Map<String, dynamic>.from(j['log'] as Map);
        final prayer = PrayerName.values.asNameMap()[l['prayer']];
        if (prayer == null) return null;
        return PrayerLoggedEvent(
          eventId: eventId,
          emittedAt: emittedAt,
          groupId: groupId,
          log: LiveLog(
            id: l['id'] as String,
            userId: l['userId'] as String,
            prayer: prayer,
            date: l['date'] as String,
            points: (l['points'] as num).toInt(),
            loggedAt: DateTime.parse(l['loggedAt'] as String).toUtc(),
            hasSnap: l['hasSnap'] == true,
          ),
          member: MemberSnapshot.fromJson(
            Map<String, dynamic>.from(j['member'] as Map),
          ),
          group: GroupNumbers.fromJson(
            Map<String, dynamic>.from(j['group'] as Map),
          ),
        );
      case prayerDeletedEventName:
        return PrayerDeletedEvent(
          eventId: eventId,
          emittedAt: emittedAt,
          groupId: groupId,
          logId: j['logId'] as String,
          userId: j['userId'] as String,
          member: MemberSnapshot.fromJson(
            Map<String, dynamic>.from(j['member'] as Map),
          ),
          group: GroupNumbers.fromJson(
            Map<String, dynamic>.from(j['group'] as Map),
          ),
        );
      case groupChangedEventName:
        return GroupChangedEvent(
          eventId: eventId,
          emittedAt: emittedAt,
          groupId: groupId,
          reason: GroupChangeReason.parse(j['reason'] as String?),
        );
    }
  } on TypeError {
    return null;
  } on FormatException {
    return null;
  }
  return null;
}
