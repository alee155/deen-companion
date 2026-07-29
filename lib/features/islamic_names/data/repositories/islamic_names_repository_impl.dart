import '../../../../core/cache/hive_cache_store.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../../core/utils/logger.dart';
import '../../domain/entities/islamic_name.dart';
import '../../domain/repositories/islamic_names_repository.dart';
import '../datasources/islamic_names_remote_datasource.dart';
import '../models/islamic_name_model.dart';

class IslamicNamesRepositoryImpl implements IslamicNamesRepository {
  final IslamicNamesRemoteDataSource remoteDataSource;
  final HiveCacheStore cacheStore;
  final NetworkInfo networkInfo;

  const IslamicNamesRepositoryImpl({
    required this.remoteDataSource,
    required this.cacheStore,
    required this.networkInfo,
  });

  static const _cacheKey = 'islamic_names_all';
  static const _cacheTtl = Duration(days: 90); // curated, static content

  @override
  List<IslamicName>? getCachedNames() {
    final cached = cacheStore.read<List<dynamic>>(
      _cacheKey,
      (json) => json['list'] as List<dynamic>,
    );
    return cached?.data
        .map(
          (e) =>
              IslamicNameModel.fromJson(e as Map<String, dynamic>).toEntity(),
        )
        .toList();
  }

  @override
  Future<Result<List<IslamicName>>> fetchAndCacheNames({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      final cachedRaw = cacheStore.read<List<dynamic>>(
        _cacheKey,
        (json) => json['list'] as List<dynamic>,
      );
      if (cachedRaw != null && !cachedRaw.isStale(_cacheTtl))
        return Success(getCachedNames()!);
    }

    if (!await networkInfo.isConnected) {
      final cached = getCachedNames();
      if (cached != null) return Success(cached);
      return const Error(NetworkFailure());
    }

    try {
      final models = await remoteDataSource.getAllNames();
      await cacheStore.save<List<dynamic>>(
        _cacheKey,
        models.map((m) => m.toJson()).toList(),
        (list) => {'list': list},
      );
      return Success(models.map((m) => m.toEntity()).toList());
    } on ServerException catch (e) {
      final cached = getCachedNames();
      if (cached != null) return Success(cached);
      return Error(
        ServerFailure(
          e.message ?? 'Something went wrong on our end. Try again.',
        ),
      );
    } catch (e, stackTrace) {
      AppLogger.e('IslamicNamesRepository: unexpected error', e, stackTrace);
      return const Error(UnexpectedFailure());
    }
  }
}
