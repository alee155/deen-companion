import '../../domain/entities/group.dart';
import '../../domain/entities/group_streak.dart';

/// In-memory stand-in for the groups API.
///
/// TODO(groups-backend): replace with a remote data source. Everything above
/// this class (repository, providers, screens) already speaks in domain
/// entities, so swapping the source should not touch presentation code.
class GroupsLocalDataSource {
  final List<Group> _groups = [
    const Group(
      id: 'family-quran-circle',
      name: 'Family Quran Circle',
      description: 'Read Quran together with family.',
      imagePath: 'assets/images/slider_1.jpg',
      privacy: GroupPrivacy.private,
      memberCount: 10,
      requiresApproval: true,
      isOwner: true,
    ),
    const Group(
      id: 'daily-quran-reading',
      name: 'Daily Quran Reading',
      description: 'A daily Quran reading circle.',
      imagePath: 'assets/images/slider_1.jpg',
      privacy: GroupPrivacy.public,
      memberCount: 24,
    ),
    const Group(
      id: 'friends-hifz-group',
      name: 'Friends Hifz Group',
      description: 'Stay consistent with memorization.',
      imagePath: 'assets/images/slider_1.jpg',
      privacy: GroupPrivacy.private,
      memberCount: 8,
      requiresApproval: true,
      isOwner: true,
    ),
  ];

  List<Group> groups() => List.unmodifiable(_groups);

  Group add(NewGroup input) {
    final group = Group(
      id: 'g${DateTime.now().microsecondsSinceEpoch}',
      name: input.name,
      description: input.description,
      imagePath: input.imagePath,
      privacy: input.privacy,
      memberCount: 1,
      requiresApproval: input.adminApproval,
      isOwner: true,
    );
    _groups.insert(0, group);
    return group;
  }

  Group? byId(String id) {
    for (final g in _groups) {
      if (g.id == id) return g;
    }
    return null;
  }

  static const _memberSeed = [
    ('Muhammad Ali', 'assets/images/boy_name.png', 7, true),
    ('Ahmed Khan', 'assets/images/girl_name.jpeg', 6, true),
    ('Usman Ali', 'assets/images/boy_name.png', 5, false),
    ('Hamza Ahmed', 'assets/images/girl_name.jpeg', 4, true),
  ];

  /// Monday-first booleans for this week: every day before today is done.
  List<bool> _myWeek(int todayIndex) => [
    for (var i = 0; i < 7; i++) i < todayIndex,
  ];

  GroupStreakSummary streakFor(Group group) {
    final now = DateTime.now();
    final todayIndex = now.weekday - 1;
    final monday = DateTime(now.year, now.month, now.day - todayIndex);
    final done = _myWeek(todayIndex);

    final members = [
      for (var i = 0; i < _memberSeed.length; i++)
        MemberActivity(
          id: 'm$i',
          name: _memberSeed[i].$1,
          imagePath: _memberSeed[i].$2,
          streakDays: _memberSeed[i].$3,
          completedToday: _memberSeed[i].$4,
        ),
    ];
    final completed = (group.memberCount * 0.75).round();

    return GroupStreakSummary(
      groupId: group.id,
      groupName: group.name,
      currentStreak: todayIndex + 7,
      longestStreak: todayIndex + 12,
      week: [
        for (var i = 0; i < 7; i++)
          StreakDay(
            date: monday.add(Duration(days: i)),
            completed: done[i],
            isToday: i == todayIndex,
          ),
      ],
      memberCount: group.memberCount,
      completedTodayCount: completed.clamp(0, group.memberCount),
      members: members,
    );
  }

  UserStreakStats myStats() {
    final todayIndex = DateTime.now().weekday - 1;
    return UserStreakStats(
      currentStreak: todayIndex + 7,
      longestStreak: todayIndex + 12,
      week: _myWeek(todayIndex),
      todayIndex: todayIndex,
    );
  }
}
