import 'package:deen_companion/features/groups/domain/entities/group.dart';
import 'package:deen_companion/features/prayer_logs/domain/group_member_prayers.dart';
import 'package:deen_companion/features/prayer_logs/domain/prayer_log.dart';
import 'package:deen_companion/features/prayer_times/domain/entities/prayer_times.dart';
import 'package:flutter_test/flutter_test.dart';

PrayerLog _log(
  PrayerName prayer,
  DateTime at, {
  bool snap = false,
  bool viewed = false,
  bool expired = false,
}) => PrayerLog(
  id: '${prayer.name}-${at.hour}',
  prayer: prayer,
  date: '2026-10-13',
  status: PrayerLogStatus.onTime,
  points: 5,
  snapUrl: null,
  hasSnap: snap,
  snapViewed: viewed,
  snapExpired: expired,
  windowStartsAt: at,
  windowEndsAt: at.add(const Duration(hours: 1)),
  loggedAt: at,
);

GroupMemberPrayers _member(List<PrayerLog> logs) => GroupMemberPrayers(
  userId: 'u',
  name: 'Sara',
  role: GroupRole.member,
  logs: logs,
);

void main() {
  final t = DateTime(2026, 10, 13, 12);

  group('latestSnapLog', () {
    test('is the most recently logged prayer that has a snap', () {
      final m = _member([
        _log(PrayerName.fajr, t, snap: true),
        _log(PrayerName.asr, t.add(const Duration(hours: 3)), snap: true),
        _log(PrayerName.dhuhr, t.add(const Duration(hours: 1)), snap: true),
      ]);
      expect(m.latestSnapLog(t)!.prayer, PrayerName.asr);
    });

    test('ignores logs without a snap, even if they are newer', () {
      final m = _member([
        _log(PrayerName.fajr, t, snap: true),
        _log(PrayerName.maghrib, t.add(const Duration(hours: 6))),
      ]);
      expect(m.latestSnapLog(t)!.prayer, PrayerName.fajr);
    });

    test('is null when nothing was logged, or nothing has a snap', () {
      expect(_member([]).latestSnapLog(t), isNull);
      expect(_member([_log(PrayerName.fajr, t)]).latestSnapLog(t), isNull);
    });

    test('counts opened and expired snaps, so the tile can say so', () {
      final opened = _log(PrayerName.fajr, t, viewed: true);
      final expired = _log(
        PrayerName.dhuhr,
        t.add(const Duration(hours: 1)),
        expired: true,
      );
      expect(_member([opened]).latestSnapLog(t), opened);
      expect(_member([opened, expired]).latestSnapLog(t), expired);
    });

    test('does not depend on the order of the list', () {
      final a = _log(PrayerName.fajr, t, snap: true);
      final b = _log(
        PrayerName.isha,
        t.add(const Duration(hours: 9)),
        snap: true,
      );
      expect(_member([a, b]).latestSnapLog(t), b);
      expect(_member([b, a]).latestSnapLog(t), b);
    });
  });
}
