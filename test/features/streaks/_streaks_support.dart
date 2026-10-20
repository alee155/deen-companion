import 'package:deen_companion/core/error/failures.dart';
import 'package:deen_companion/core/usecase/usecase.dart';
import 'package:deen_companion/features/groups/domain/entities/group.dart';
import 'package:deen_companion/features/prayer_times/domain/entities/prayer_times.dart';
import 'package:deen_companion/features/streaks/domain/entities/group_streaks.dart';
import 'package:deen_companion/features/streaks/domain/entities/my_streaks.dart';
import 'package:deen_companion/features/streaks/domain/entities/streak_rule.dart';
import 'package:deen_companion/features/streaks/domain/repositories/streaks_repository.dart';

MemberStreak entry(
  String id, {
  String? name,
  int current = 0,
  int best = 0,
  int count = 0,
  int required = 1,
  GroupRole role = GroupRole.member,
}) => MemberStreak(
  userId: id,
  name: name ?? id,
  role: role,
  currentStreak: current,
  bestStreak: best,
  todayCount: count,
  todayRequired: required,
  todayQualified: count >= required,
);

/// A scriptable [StreaksRepository]: set the results, read the calls.
class FakeStreaksRepo implements StreaksRepository {
  Result<StreakRule> rule = Success(
    StreakRule(minPrayers: 1, effectiveFrom: DateTime.utc(2026)),
  );
  Result<GroupStreakBoard> board = Success(
    GroupStreakBoard([
      entry('admin1', name: 'Alee Khan', current: 4, best: 9, count: 1),
      entry('member1', name: 'Sara Ahmed', current: 2, best: 3),
    ]),
  );
  Result<MyStreaks> mine = const Success(MyStreaks.empty);

  /// When true, saving a rule is rejected.
  bool setRuleFails = false;

  final List<int> setRuleCalls = [];
  int boardCalls = 0;
  int mineCalls = 0;

  @override
  Future<Result<StreakRule>> getRule(String groupId) async => rule;

  @override
  Future<Result<StreakRule>> setRule(String groupId, int minPrayers) async {
    setRuleCalls.add(minPrayers);
    if (setRuleFails) {
      return const Error(ServerFailure('Only the admin can do this'));
    }
    final r = rule;
    if (r is Success<StreakRule>) {
      rule = Success(
        StreakRule(minPrayers: minPrayers, effectiveFrom: DateTime.utc(2026)),
      );
      return rule;
    }
    return r;
  }

  @override
  Future<Result<GroupStreakBoard>> getBoard(String groupId) async {
    boardCalls++;
    return board;
  }

  @override
  Future<Result<MyStreaks>> getMine() async {
    mineCalls++;
    return mine;
  }
}

const offline = Error<Never>(NetworkFailure());

MyStreaks sampleMine() => const MyStreaks(
  groups: [
    GroupStreakSummary(
      groupId: 'g1',
      name: 'Family',
      currentStreak: 7,
      bestStreak: 12,
      minPrayers: 3,
    ),
    GroupStreakSummary(
      groupId: 'g2',
      name: 'Friends',
      currentStreak: 2,
      bestStreak: 20,
      minPrayers: 1,
    ),
  ],
  prayers: {
    PrayerName.fajr: PrayerStreak(currentStreak: 12, bestStreak: 30),
    PrayerName.dhuhr: PrayerStreak(currentStreak: 3, bestStreak: 5),
  },
);

/// Rules for tests.
class StreakRuleFixture {
  static StreakRule rule(int n) =>
      StreakRule(minPrayers: n, effectiveFrom: DateTime.utc(2026));
}
