import 'dart:math';
import '../../../../core/usecase/usecase.dart';
import '../../domain/entities/group_streak.dart';
import '../../domain/entities/member_snap_stats.dart';
import '../../domain/repositories/snap_stats_repository.dart';

/// MOCK snap statistics — sample numbers only, generated deterministically
/// from the ids so the UI is stable between rebuilds.
///
/// TODO(snaps-backend): delete this file and provide a real
/// [SnapStatsRepository] (remote data source + models) when the API ships.
/// Nothing else in the feature references this class except the provider.
class MockSnapStatsRepository implements SnapStatsRepository {
  const MockSnapStatsRepository();

  static const activityDays = 14;
  static const _captions = [
    'Fajr recitation',
    'Surah Al-Mulk',
    'Daily page done',
    'Ayat al-Kursi',
    'Evening dhikr',
    null,
  ];

  @override
  Future<Result<GroupSnapOverview>> getGroupOverview({
    required String groupId,
    required List<String> memberIds,
  }) async {
    final now = DateTime.now();
    final todayIndex = now.weekday - 1;
    final monday = DateTime(now.year, now.month, now.day - todayIndex);
    final members = {for (final id in memberIds) id: _statsFor(id, now)};
    final seed = _hash(groupId);

    return Success(
      GroupSnapOverview(
        currentStreak: 3 + seed % 20,
        longestStreak: 25 + seed % 15,
        week: [
          for (var i = 0; i < 7; i++)
            StreakDay(
              date: monday.add(Duration(days: i)),
              completed: i < todayIndex,
              isToday: i == todayIndex,
            ),
        ],
        snappedTodayCount: members.values.where((m) => m.snappedToday).length,
        memberCount: memberIds.length,
        members: members,
      ),
    );
  }

  MemberSnapStats _statsFor(String userId, DateTime now) {
    final rnd = Random(_hash(userId));
    final daily = [for (var i = 0; i < activityDays; i++) rnd.nextInt(4)];
    final snappedToday = daily.last > 0;
    final total = 40 + rnd.nextInt(260);
    final recent = [
      for (var i = 0; i < 6; i++)
        SnapItem(
          id: '$userId-$i',
          sentAt: now.subtract(Duration(hours: 3 + i * 19 + rnd.nextInt(6))),
          caption: _captions[rnd.nextInt(_captions.length)],
          viewed: i > 1,
        ),
    ];
    return MemberSnapStats(
      userId: userId,
      totalSnaps: total,
      score: total * 10 + rnd.nextInt(90),
      streakDays: rnd.nextInt(30),
      snappedToday: snappedToday,
      dailyActivity: daily,
      recentSnaps: recent,
    );
  }

  static int _hash(String s) =>
      s.codeUnits.fold(7, (h, c) => (h * 31 + c) & 0x3fffffff);
}
