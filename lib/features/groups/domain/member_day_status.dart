export '../../prayer_logs/domain/day_prayers.dart' show DayPrayer;
import 'package:equatable/equatable.dart';

import '../../prayer_logs/domain/current_prayer.dart';
import '../../prayer_logs/domain/day_prayers.dart';
import '../../prayer_logs/domain/group_member_prayers.dart';
import '../../prayer_times/domain/entities/prayer_times.dart';

/// A member's day at a glance: the five prayers as logged / missed / pending,
/// and, while a prayer's time is open and they have not logged it yet, which
/// prayer and how long is left (until the next prayer starts).
class MemberDayStatus extends Equatable {
  /// Fajr to Isha, in order. Empty when today's feed has not loaded, so the
  /// row shows nothing rather than a row of "missed".
  final List<DayPrayer> days;

  /// The open prayer this member has not logged, or null.
  final PrayerName? waitingFor;

  /// Time left in that prayer's window; set with [waitingFor].
  final Duration? left;

  const MemberDayStatus({this.days = const [], this.waitingFor, this.left});

  @override
  List<Object?> get props => [days, waitingFor, left];
}

/// Works out [MemberDayStatus] from today's feed row and the server's answer
/// about the open prayer. [now] is the server's clock.
///
/// Which prayers count as missed is decided by [dayPrayers], the same rule
/// Home uses.
MemberDayStatus memberDayStatus({
  required GroupMemberPrayers? prayers,
  required CurrentPrayerState? window,
  required DateTime now,
}) {
  if (prayers == null) return const MemberDayStatus();
  final open = window?.current;
  final stillOpen = open != null && now.isBefore(open.endsAt);

  final days = dayPrayers(
    done: {
      for (final p in PrayerName.values)
        if (prayers.logFor(p) != null) p,
    },
    window: window,
    now: now,
  );

  if (stillOpen && prayers.logFor(open.prayer) == null) {
    return MemberDayStatus(
      days: days,
      waitingFor: open.prayer,
      left: open.endsAt.difference(now),
    );
  }
  return MemberDayStatus(days: days);
}
