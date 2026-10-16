import '../../../../core/cache/hive_cache_store.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../../core/utils/flow_log.dart';
import '../../../../core/utils/logger.dart';
import '../../domain/entities/points_rule.dart';
import '../../domain/repositories/points_repository.dart';
import '../datasources/points_remote_datasource.dart';
import '../models/points_rule_model.dart';

const _cacheKey = 'points_rules';
const _tag = 'POINTS RULES';

class PointsRepositoryImpl implements PointsRepository {
  final PointsRemoteDataSource remote;
  final HiveCacheStore cacheStore;

  const PointsRepositoryImpl({required this.remote, required this.cacheStore});

  @override
  PointsRules? getCachedRules() {
    try {
      return cacheStore
          .read<PointsRulesModel>(_cacheKey, PointsRulesModel.fromJson)
          ?.data
          .toEntity();
    } catch (e, st) {
      // A cache written by another build must never break the screen.
      AppLogger.e('PointsRepository: unreadable cache ignored', e, st);
      return null;
    }
  }

  @override
  Future<Result<PointsRules>> fetchRules() async {
    FlowLog.log(_tag, 'FETCHING THE RULES FROM THE SERVER');
    try {
      final model = await remote.getRules();
      await cacheStore.save<PointsRulesModel>(
        _cacheKey,
        model,
        (m) => m.toJson(),
      );
      final rules = model.toEntity();
      FlowLog.data(_tag, 'RULES RECEIVED', [
        for (final r in rules.rules) '${r.prayer}: ${r.points}',
      ]);
      return Success(rules);
    } on NetworkException {
      FlowLog.error(_tag, 'NO CONNECTION');
      return const Error(NetworkFailure());
    } on ServerException catch (e) {
      FlowLog.error(_tag, 'SERVER ERROR', e.message);
      final m = e.message;
      return Error(m == null ? const ServerFailure() : ServerFailure(m));
    } catch (e, st) {
      AppLogger.e('PointsRepository: fetchRules failed', e, st);
      return const Error(UnexpectedFailure());
    }
  }
}
