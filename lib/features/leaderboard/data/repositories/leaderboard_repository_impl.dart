import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../../core/utils/flow_log.dart';
import '../../../../core/utils/logger.dart';
import '../../domain/entities/leaderboard_entry.dart';
import '../../domain/repositories/leaderboard_repository.dart';
import '../datasources/leaderboard_remote_datasource.dart';

const _tag = 'LEADERBOARD';

class LeaderboardRepositoryImpl implements LeaderboardRepository {
  final LeaderboardRemoteDataSource remote;
  const LeaderboardRepositoryImpl(this.remote);

  @override
  Future<Result<List<LeaderboardEntry>>> leaderboard(String groupId) async {
    try {
      final rows = await remote.leaderboard(groupId);
      FlowLog.log(_tag, 'LEADERBOARD: ${rows.length} members');
      return Success(rows);
    } on NetworkException {
      FlowLog.error(_tag, 'leaderboard: NO CONNECTION');
      return const Error(NetworkFailure());
    } on NotFoundException {
      return const Error(NotFoundFailure());
    } on ServerException catch (e) {
      FlowLog.error(
        _tag,
        'leaderboard: SERVER ERROR',
        '${e.statusCode} ${e.message}',
      );
      final m = e.message;
      return Error(m == null ? const ServerFailure() : ServerFailure(m));
    } catch (e, st) {
      AppLogger.e('LeaderboardRepository: leaderboard failed', e, st);
      return const Error(UnexpectedFailure());
    }
  }
}
