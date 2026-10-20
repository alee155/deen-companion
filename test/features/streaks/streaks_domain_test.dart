import 'package:deen_companion/features/prayer_times/domain/entities/prayer_times.dart';
import 'package:deen_companion/features/streaks/domain/entities/group_streaks.dart';
import 'package:deen_companion/features/streaks/domain/entities/my_streaks.dart';
import 'package:deen_companion/features/streaks/domain/entities/streak_rule.dart';
import 'package:flutter_test/flutter_test.dart';

import '_streaks_support.dart';

void main() {
  group('StreakRule.summary', () {
    StreakRule r(int n) =>
        StreakRule(minPrayers: n, effectiveFrom: DateTime.utc(2026));
    test('says what a day needs', () {
      expect(r(1).summary, 'Log at least 1 prayer a day');
      expect(r(3).summary, 'Log at least 3 prayers a day');
      expect(r(5).summary, 'Log all 5 prayers every day');
    });

    test('the standard rule is one prayer a day', () {
      expect(StreakRule.standard.minPrayers, 1);
    });
  });

  group('MemberStreak.todayProgress', () {
    test('is count over required, capped at 1', () {
      expect(entry('a', count: 1, required: 4).todayProgress, 0.25);
      expect(entry('a', count: 5, required: 3).todayProgress, 1);
      expect(entry('a', count: 0, required: 0).todayProgress, 1);
    });
  });

  group('GroupStreakBoard', () {
    final board = GroupStreakBoard([
      entry('a', count: 1, required: 1),
      entry('b', count: 0, required: 1),
      entry('c', count: 2, required: 1),
    ]);

    test('finds a member, and null for strangers and no user', () {
      expect(board.of('b')?.userId, 'b');
      expect(board.of('zzz'), isNull);
      expect(board.of(null), isNull);
    });

    test('counts who is done today', () {
      expect(board.doneToday, 2);
    });

    test('knows what a day needs', () {
      expect(board.required, 1);
      expect(const GroupStreakBoard([]).required, isNull);
      expect(const GroupStreakBoard([]).isEmpty, isTrue);
    });
  });

  group('MyStreaks', () {
    final mine = sampleMine();

    test('current best and longest are the maxima across groups', () {
      expect(mine.currentBest, 7);
      expect(mine.longest, 20);
    });

    test('the leading group is the one with the longest current run', () {
      expect(mine.leading?.name, 'Family');
    });

    test('a prayer with no entry reads as zero', () {
      expect(mine.prayer(PrayerName.fajr).currentStreak, 12);
      expect(mine.prayer(PrayerName.maghrib), PrayerStreak.none);
    });

    test('empty has nothing to lead or show', () {
      expect(MyStreaks.empty.currentBest, 0);
      expect(MyStreaks.empty.longest, 0);
      expect(MyStreaks.empty.leading, isNull);
      expect(MyStreaks.empty.isBlank, isTrue);
      expect(mine.isBlank, isFalse);
    });
  });
}
