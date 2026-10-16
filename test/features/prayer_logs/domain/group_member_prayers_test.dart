import 'package:deen_companion/features/groups/domain/entities/group.dart';
import 'package:deen_companion/features/prayer_logs/domain/group_member_prayers.dart';
import 'package:deen_companion/features/prayer_logs/domain/prayer_log.dart';
import 'package:deen_companion/features/prayer_times/domain/entities/prayer_times.dart';
import 'package:flutter_test/flutter_test.dart';

PrayerLog _log(PrayerName prayer, DateTime at, {String? url}) => PrayerLog(
  id: '${prayer.name}-${at.hour}',
  prayer: prayer,
  date: '2026-10-13',
  status: PrayerLogStatus.onTime,
  points: 5,
  snapUrl: url,
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

  group('latestPhotoLog', () {
    test('is the most recently logged prayer that has a photo', () {
      final m = _member([
        _log(PrayerName.fajr, t, url: 'a'),
        _log(PrayerName.asr, t.add(const Duration(hours: 3)), url: 'b'),
        _log(PrayerName.dhuhr, t.add(const Duration(hours: 1)), url: 'c'),
      ]);
      expect(m.latestPhotoLog!.prayer, PrayerName.asr);
    });

    test('ignores logs without a photo, even if they are newer', () {
      final m = _member([
        _log(PrayerName.fajr, t, url: 'a'),
        _log(PrayerName.maghrib, t.add(const Duration(hours: 6))),
      ]);
      expect(m.latestPhotoLog!.prayer, PrayerName.fajr);
    });

    test('is null when nothing was logged, or nothing has a photo', () {
      expect(_member([]).latestPhotoLog, isNull);
      expect(_member([_log(PrayerName.fajr, t)]).latestPhotoLog, isNull);
    });

    test('does not depend on the order of the list', () {
      final a = _log(PrayerName.fajr, t, url: 'a');
      final b = _log(
        PrayerName.isha,
        t.add(const Duration(hours: 9)),
        url: 'b',
      );
      expect(_member([a, b]).latestPhotoLog, b);
      expect(_member([b, a]).latestPhotoLog, b);
    });
  });
}
