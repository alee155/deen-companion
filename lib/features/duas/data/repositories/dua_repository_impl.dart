import '../../../../core/cache/hive_cache_store.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../../core/utils/logger.dart';
import '../../domain/entities/dua.dart';
import '../../domain/entities/duas_bundle.dart';
import '../../domain/repositories/dua_repository.dart';
import '../datasources/dua_remote_datasource.dart';
import '../models/dua_model.dart';
import '../models/duas_bundle_model.dart';

class DuaRepositoryImpl implements DuaRepository {
  final DuaRemoteDataSource remoteDataSource;
  final HiveCacheStore cacheStore;
  final NetworkInfo networkInfo;

  const DuaRepositoryImpl({
    required this.remoteDataSource,
    required this.cacheStore,
    required this.networkInfo,
  });

  static const _bundleCacheKey = 'duas_bundle';
  static const _bundleCacheTtl = Duration(days: 30); // static content
  static const _searchCacheTtl = Duration(hours: 1);

  String _searchCacheKey(String query) => 'duas_search_${query.toLowerCase()}';

  @override
  DuasBundle? getCachedBundle() {
    return cacheStore
        .read(_bundleCacheKey, DuasBundleModel.fromJson)
        ?.data
        .toEntity();
  }

  @override
  Future<Result<DuasBundle>> fetchAndCacheBundle({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      final cached = cacheStore.read(_bundleCacheKey, DuasBundleModel.fromJson);
      if (cached != null && !cached.isStale(_bundleCacheTtl)) {
        return Success(cached.data.toEntity());
      }
    }

    if (!await networkInfo.isConnected) {
      final cached = getCachedBundle();
      if (cached != null) return Success(cached);
      return const Error(NetworkFailure());
    }

    try {
      final model = await remoteDataSource.getBundle();
      await cacheStore.save(_bundleCacheKey, model, (m) => m.toJson());
      return Success(model.toEntity());
    } on ServerException catch (e) {
      final cached = getCachedBundle();
      if (cached != null) return Success(cached);
      return Error(
        ServerFailure(
          e.message ?? 'Something went wrong on our end. Try again.',
        ),
      );
    } catch (e, stackTrace) {
      AppLogger.e('DuaRepository: unexpected error (bundle)', e, stackTrace);
      return const Error(UnexpectedFailure());
    }
  }

  @override
  Future<Result<List<Dua>>> search(String query) async {
    final key = _searchCacheKey(query);
    final cachedRaw = cacheStore.read<List<dynamic>>(
      key,
      (json) => json['list'] as List<dynamic>,
    );
    if (cachedRaw != null && !cachedRaw.isStale(_searchCacheTtl)) {
      return Success(
        cachedRaw.data
            .map((e) => DuaModel.fromJson(e as Map<String, dynamic>).toEntity())
            .toList(),
      );
    }

    if (!await networkInfo.isConnected) {
      if (cachedRaw != null) {
        return Success(
          cachedRaw.data
              .map(
                (e) => DuaModel.fromJson(e as Map<String, dynamic>).toEntity(),
              )
              .toList(),
        );
      }
      return const Error(NetworkFailure());
    }

    try {
      final response = await remoteDataSource.search(query);
      await cacheStore.save<List<dynamic>>(
        key,
        response.results.map((r) => r.toJson()).toList(),
        (list) => {'list': list},
      );
      return Success(response.results.map((r) => r.toEntity()).toList());
    } on ServerException catch (e) {
      if (cachedRaw != null) {
        return Success(
          cachedRaw.data
              .map(
                (e) => DuaModel.fromJson(e as Map<String, dynamic>).toEntity(),
              )
              .toList(),
        );
      }
      return Error(
        ServerFailure(
          e.message ?? 'Something went wrong on our end. Try again.',
        ),
      );
    } catch (e, stackTrace) {
      AppLogger.e('DuaRepository: unexpected error (search)', e, stackTrace);
      return const Error(UnexpectedFailure());
    }
  }
}
