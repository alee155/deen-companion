import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../../core/utils/logger.dart';
import '../../domain/entities/group.dart';
import '../../domain/entities/group_streak.dart';
import '../../domain/repositories/groups_repository.dart';
import '../datasources/groups_local_datasource.dart';

class GroupsRepositoryImpl implements GroupsRepository {
  final GroupsLocalDataSource dataSource;
  const GroupsRepositoryImpl(this.dataSource);

  @override
  Future<Result<List<Group>>> getMyGroups() async {
    try {
      return Success(dataSource.groups());
    } catch (e, st) {
      AppLogger.e('GroupsRepository: getMyGroups failed', e, st);
      return const Error(UnexpectedFailure());
    }
  }

  @override
  Future<Result<Group>> createGroup(NewGroup input) async {
    try {
      // Simulated latency until the API exists.
      await Future<void>.delayed(const Duration(milliseconds: 700));
      return Success(dataSource.add(input));
    } catch (e, st) {
      AppLogger.e('GroupsRepository: createGroup failed', e, st);
      return const Error(UnexpectedFailure());
    }
  }

  @override
  Future<Result<GroupStreakSummary>> getGroupStreak(String groupId) async {
    try {
      final group = dataSource.byId(groupId);
      if (group == null) return const Error(NotFoundFailure());
      return Success(dataSource.streakFor(group));
    } catch (e, st) {
      AppLogger.e('GroupsRepository: getGroupStreak failed', e, st);
      return const Error(UnexpectedFailure());
    }
  }

  @override
  Future<Result<UserStreakStats>> getMyStreakStats() async {
    try {
      return Success(dataSource.myStats());
    } catch (e, st) {
      AppLogger.e('GroupsRepository: getMyStreakStats failed', e, st);
      return const Error(UnexpectedFailure());
    }
  }
}
