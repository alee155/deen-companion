import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/cache/cache_first_stream_notifier.dart';
import '../../../../core/cache/hive_cache_store.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../../core/utils/flow_log.dart';
import '../../data/datasources/points_remote_datasource.dart';
import '../../data/repositories/points_repository_impl.dart';
import '../../domain/entities/points_rule.dart';
import '../../domain/repositories/points_repository.dart';

final pointsRemoteDataSourceProvider = Provider<PointsRemoteDataSource>(
  (ref) => PointsRemoteDataSourceImpl(ref.watch(dioProvider)),
);

final pointsRepositoryProvider = Provider<PointsRepository>(
  (ref) => PointsRepositoryImpl(
    remote: ref.watch(pointsRemoteDataSourceProvider),
    cacheStore: ref.watch(hiveCacheStoreProvider),
  ),
);

/// The points each prayer earns, cache-first: the last table shows at once and
/// the server's answer replaces it if it differs.
class PointsRulesNotifier extends CacheFirstStreamNotifier<PointsRules> {
  @override
  PointsRules? readCache() {
    final cached = ref.read(pointsRepositoryProvider).getCachedRules();
    FlowLog.log(
      'POINTS RULES',
      cached == null
          ? 'SCREEN OPENED: nothing cached, loading'
          : 'SCREEN OPENED: showing ${cached.rules.length} cached rules first',
    );
    return cached;
  }

  @override
  Future<Result<PointsRules>> fetchFresh() =>
      ref.read(pointsRepositoryProvider).fetchRules();

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}

final pointsRulesProvider =
    StreamNotifierProvider<PointsRulesNotifier, PointsRules>(
      PointsRulesNotifier.new,
    );
