import 'package:deen_companion/features/groups/domain/entities/group.dart';
import 'package:deen_companion/features/groups/domain/member_day_status.dart';
import 'package:deen_companion/features/prayer_logs/domain/current_prayer.dart';
import 'package:deen_companion/features/prayer_logs/domain/group_member_prayers.dart';
import 'package:deen_companion/features/prayer_logs/domain/prayer_log.dart';
import 'package:deen_companion/features/prayer_times/domain/entities/prayer_times.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime(2026, 11, 17, 15, 40);

PrayerLog _log(PrayerName p) => PrayerLog(
  id: p.name,
  prayer: p,
  date: '2026-11-17',
  status: PrayerLogStatus.onTime,
  points: 5,
  snapUrl: null,
  windowStartsAt: _now,
  windowEndsAt: _now,
  loggedAt: _now,
);

GroupMemberPrayers _member(List<PrayerName> logged) => GroupMemberPrayers(
  userId: 'u',
  name: 'Sara',
  role: GroupRole.member,
  logs: [for (final p in logged) _log(p)],
);

/// [prayer] is open and ends [left] from [_now].
CurrentPrayerState _open(PrayerName prayer, Duration left) =>
    CurrentPrayerState(
      now: _now,
      current: CurrentPrayer(
        prayer: prayer,
        date: '2026-11-17',
        startsAt: _now.subtract(const Duration(minutes: 30)),
        endsAt: _now.add(left),
        logged: false,
        logId: null,
      ),
    );

void main() {
  const logged = DayPrayer.logged;
  const missed = DayPrayer.missed;
  const pending = DayPrayer.pending;

  test('nothing is said before today\'s feed has loaded', () {
    final s = memberDayStatus(
      prayers: null,
      window: _open(PrayerName.asr, const Duration(hours: 1)),
      now: _now,
    );
    expect(s.days, isEmpty);
    expect(s.waitingFor, isNull);
  });

  test(
    'an open prayer not yet logged: who is waiting, and how long is left',
    () {
      final s = memberDayStatus(
        prayers: _member([PrayerName.fajr, PrayerName.dhuhr]),
        window: _open(PrayerName.asr, const Duration(hours: 1, minutes: 14)),
        now: _now,
      );
      expect(s.waitingFor, PrayerName.asr);
      expect(s.left, const Duration(hours: 1, minutes: 14));
      expect(s.days, [logged, logged, pending, pending, pending]);
    },
  );

  test('having logged the open prayer means no countdown', () {
    final s = memberDayStatus(
      prayers: _member([PrayerName.asr]),
      window: _open(PrayerName.asr, const Duration(hours: 1)),
      now: _now,
    );
    expect(s.waitingFor, isNull);
    expect(s.left, isNull);
  });

  test('prayers before the open one that were not logged are missed', () {
    final s = memberDayStatus(
      prayers: _member([PrayerName.fajr]),
      window: _open(PrayerName.asr, const Duration(hours: 1)),
      now: _now,
    );
    expect(s.days, [logged, missed, pending, pending, pending]);
  });

  test('a window that has run out counts as closed and has no countdown', () {
    final s = memberDayStatus(
      prayers: _member([]),
      window: _open(PrayerName.asr, const Duration(minutes: -1)),
      now: _now,
    );
    expect(s.waitingFor, isNull);
    expect(s.days, [missed, missed, missed, pending, pending]);
  });

  test('between prayers, those before the next one are missed', () {
    final s = memberDayStatus(
      prayers: _member([PrayerName.fajr, PrayerName.dhuhr]),
      window: CurrentPrayerState(
        now: _now,
        next: NextPrayer(
          prayer: PrayerName.maghrib,
          startsAt: _now.add(const Duration(hours: 1)),
        ),
      ),
      now: _now,
    );
    expect(s.waitingFor, isNull);
    expect(s.days, [logged, logged, missed, pending, pending]);
  });

  test('when the next prayer is Fajr nothing is called missed', () {
    final s = memberDayStatus(
      prayers: _member([PrayerName.fajr]),
      window: CurrentPrayerState(
        now: _now,
        next: NextPrayer(
          prayer: PrayerName.fajr,
          startsAt: _now.add(const Duration(hours: 6)),
        ),
      ),
      now: _now,
    );
    expect(s.days, [logged, pending, pending, pending, pending]);
  });

  test('without the server\'s answer nothing is called missed', () {
    final s = memberDayStatus(
      prayers: _member([PrayerName.dhuhr]),
      window: null,
      now: _now,
    );
    expect(s.days, [pending, logged, pending, pending, pending]);
    expect(s.waitingFor, isNull);
  });
}
