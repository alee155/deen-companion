import '../../../../core/usecase/usecase.dart';
import '../entities/group.dart';
import '../entities/group_streak.dart';

abstract class GroupsRepository {
  Future<Result<List<Group>>> getMyGroups();
  Future<Result<Group>> createGroup(NewGroup input);
  Future<Result<GroupStreakSummary>> getGroupStreak(String groupId);
  Future<Result<UserStreakStats>> getMyStreakStats();
}
