import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../../core/utils/flow_log.dart';
import '../../../../core/utils/logger.dart';
import '../../domain/entities/group_streaks.dart';
import '../../domain/entities/my_streaks.dart';
import '../../domain/entities/streak_rule.dart';
import '../../domain/repositories/streaks_repository.dart';
import '../datasources/streaks_remote_datasource.dart';

const _tag = 'STREAKS';

class StreaksRepositoryImpl implements StreaksRepository {
  final StreaksRemoteDataSource remote;
  const StreaksRepositoryImpl(this.remote);

  @override
  Future<Result<StreakRule>> getRule(String groupId) => _guard(
    'getRule',
    () => remote.getRule(groupId),
    (r) => 'RULE RECEIVED: ${r.minPrayers} prayers a day',
  );

  @override
  Future<Result<StreakRule>> setRule(String groupId, int minPrayers) {
    // Never send what the server will refuse.
    if (minPrayers < StreakRule.minAllowed ||
        minPrayers > StreakRule.maxAllowed) {
      return Future.value(
        Error(
          ServerFailure(
            'Pick between ${StreakRule.minAllowed} and '
            '${StreakRule.maxAllowed} prayers.',
          ),
        ),
      );
    }
    return _guard(
      'setRule',
      () => remote.setRule(groupId, minPrayers),
      (r) => 'RULE SAVED: ${r.minPrayers} prayers a day',
    );
  }

  @override
  Future<Result<GroupStreakBoard>> getBoard(String groupId) => _guard(
    'getBoard',
    () => remote.getBoard(groupId),
    (b) =>
        'BOARD RECEIVED: ${b.entries.length} members, ${b.doneToday} done today',
  );

  @override
  Future<Result<MyStreaks>> getMine() => _guard(
    'getMine',
    remote.getMine,
    (m) =>
        'MY STREAKS RECEIVED: ${m.groups.length} groups, best now ${m.currentBest}',
  );

  Future<Result<T>> _guard<T>(
    String op,
    Future<T> Function() body,
    String Function(T) describe,
  ) async {
    try {
      final data = await body();
      FlowLog.log(_tag, describe(data));
      return Success(data);
    } on NetworkException {
      FlowLog.error(_tag, '$op: NO CONNECTION');
      return const Error(NetworkFailure());
    } on NotFoundException {
      return const Error(NotFoundFailure());
    } on ServerException catch (e) {
      FlowLog.error(_tag, '$op: SERVER ERROR', '${e.statusCode} ${e.message}');
      final m = e.message;
      return Error(m == null ? const ServerFailure() : ServerFailure(m));
    } catch (e, st) {
      AppLogger.e('StreaksRepository: $op failed', e, st);
      return const Error(UnexpectedFailure());
    }
  }
}
