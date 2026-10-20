import 'package:deen_companion/features/groups/domain/entities/group.dart';
import 'package:deen_companion/features/prayer_times/domain/entities/prayer_times.dart';
import 'package:deen_companion/features/statistics/domain/entities/group_stats.dart';
import 'package:deen_companion/features/statistics/domain/entities/stats_common.dart';
import 'package:flutter_test/flutter_test.dart';

import '_stats_support.dart';

void main() {
  group('StatsPeriod', () {
    final today = DateTime(2026, 10, 19);

    test('30 days is the server default: nothing is sent', () {
      expect(StatsPeriod.month.fromDate(today), isNull);
    });

    test('7 and 90 days send the first day, counting today', () {
      expect(StatsPeriod.week.fromDate(today), '2026-10-13');
      expect(StatsPeriod.quarter.fromDate(today), '2026-07-22');
    });

    test('crosses a month and a year boundary correctly', () {
      expect(StatsPeriod.week.fromDate(DateTime(2026, 1, 3)), '2025-12-28');
      expect(StatsPeriod.week.fromDate(DateTime(2026, 3, 3)), '2026-02-25');
    });

    test('never asks for more than the server allows (92 days)', () {
      for (final p in StatsPeriod.values) {
        expect(p.days, lessThanOrEqualTo(92));
      }
    });
  });

  group('prayerFromName', () {
    test('knows the five, and returns null for anything else', () {
      expect(prayerFromName('fajr'), PrayerName.fajr);
      expect(prayerFromName('isha'), PrayerName.isha);
      expect(prayerFromName('witr'), isNull);
      expect(prayerFromName(null), isNull);
    });
  });

  group('AttentionFlag.parse', () {
    test('maps the API names', () {
      expect(AttentionFlag.parse('never_logged'), AttentionFlag.neverLogged);
      expect(AttentionFlag.parse('inactive'), AttentionFlag.inactive);
      expect(AttentionFlag.parse('declining'), AttentionFlag.declining);
      expect(AttentionFlag.parse('what'), isNull);
    });
  });

  test('member names fall back when the name is empty', () {
    expect(memberStat('u', name: '  ').displayName, 'Member');
    expect(
      const MemberIdentity(
        userId: 'u',
        name: '',
        role: GroupRole.member,
        joinedAt: null,
      ).displayName,
      'Member',
    );
  });
}
