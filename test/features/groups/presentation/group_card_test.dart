import 'package:deen_companion/features/groups/presentation/widgets/group_card.dart';
import 'package:deen_companion/features/prayer_logs/domain/group_member_prayers.dart';
import 'package:deen_companion/features/prayer_logs/domain/prayer_log.dart';
import 'package:deen_companion/features/groups/domain/entities/group.dart';
import 'package:deen_companion/features/prayer_times/domain/entities/prayer_times.dart';
import 'package:flutter_test/flutter_test.dart';

PrayerLog _log(PrayerName p, DateTime at, {bool snap = false}) => PrayerLog(
  id: '${p.name}-${at.millisecondsSinceEpoch}',
  prayer: p,
  date: '2026-11-16',
  status: PrayerLogStatus.onTime,
  points: 10,
  snapUrl: null,
  hasSnap: snap,
  windowKnown: false,
  windowStartsAt: at,
  windowEndsAt: at.add(const Duration(hours: 2)),
  loggedAt: at,
);

GroupMemberPrayers _member(String id, String name, List<PrayerLog> logs) =>
    GroupMemberPrayers(
      userId: id,
      name: name,
      role: GroupRole.member,
      logs: logs,
    );

void main() {
  final now = DateTime(2026, 11, 16, 16);

  group('shortAgo', () {
    test('is as short as it can be', () {
      expect(shortAgo(const Duration(seconds: 20)), 'now');
      expect(shortAgo(const Duration(minutes: 1)), '1m');
      expect(shortAgo(const Duration(minutes: 59)), '59m');
      expect(shortAgo(const Duration(hours: 2, minutes: 30)), '2h');
      expect(shortAgo(const Duration(days: 3)), '3d');
    });
  });

  group('latestGroupActivity', () {
    test('is null until the feed has loaded', () {
      expect(latestGroupActivity(null, me: 'u1', now: now), isNull);
    });

    test('is null when nobody has logged anything', () {
      final feed = [_member('u2', 'Hamza Ali', const [])];
      expect(latestGroupActivity(feed, me: 'u1', now: now), isNull);
    });

    test('names the newest log: first name, verb, prayer and how long ago', () {
      final feed = [
        _member('u2', 'Hamza Ali', [
          _log(
            PrayerName.asr,
            now.subtract(const Duration(minutes: 1)),
            snap: true,
          ),
        ]),
        _member('u3', 'Ayesha Khan', [
          _log(PrayerName.dhuhr, now.subtract(const Duration(hours: 3))),
        ]),
      ];
      expect(
        latestGroupActivity(feed, me: 'u1', now: now),
        'Hamza snapped Asr · 1m',
      );
    });

    test('a log without a snap is "prayed"', () {
      final feed = [
        _member('u3', 'Ayesha Khan', [
          _log(PrayerName.dhuhr, now.subtract(const Duration(hours: 3))),
        ]),
      ];
      expect(
        latestGroupActivity(feed, me: 'u1', now: now),
        'Ayesha prayed Dhuhr · 3h',
      );
    });

    test('your own log reads "You"', () {
      final feed = [
        _member('u1', 'Me Myself', [
          _log(PrayerName.fajr, now.subtract(const Duration(minutes: 5))),
        ]),
      ];
      expect(
        latestGroupActivity(feed, me: 'u1', now: now),
        'You prayed Fajr · 5m',
      );
    });
  });
}
