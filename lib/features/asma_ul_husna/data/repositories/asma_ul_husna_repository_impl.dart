import '../../../../core/cache/hive_cache_store.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../../core/utils/logger.dart';
import '../../domain/entities/asma_daily.dart';
import '../../domain/entities/asma_name.dart';
import '../../domain/repositories/asma_ul_husna_repository.dart';
import '../datasources/asma_ul_husna_remote_datasource.dart';
import '../models/asma_daily_model.dart';
import '../models/asma_name_model.dart';

class AsmaUlHusnaRepositoryImpl implements AsmaUlHusnaRepository {
  final AsmaUlHusnaRemoteDataSource remoteDataSource;
  final HiveCacheStore cacheStore;
  final NetworkInfo networkInfo;

  const AsmaUlHusnaRepositoryImpl({
    required this.remoteDataSource,
    required this.cacheStore,
    required this.networkInfo,
  });

  static const _allNamesCacheKey = 'asma_all_names';
  static const _staticCacheTtl = Duration(
    days: 90,
  ); // this content never changes
  static const _searchCacheTtl = Duration(hours: 1);

  String _dailyCacheKey(int day) => 'asma_daily_$day';
  String _searchCacheKey(String query) => 'asma_search_${query.toLowerCase()}';

  @override
  List<AsmaName>? getCachedAllNames() {
    final cached = cacheStore.read<List<dynamic>>(
      _allNamesCacheKey,
      (json) => json['list'] as List<dynamic>,
    );
    return cached?.data
        .map(
          (e) => AsmaNameModel.fromJson(e as Map<String, dynamic>).toEntity(),
        )
        .toList();
  }

  @override
  Future<Result<List<AsmaName>>> fetchAndCacheAllNames({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      final cachedRaw = cacheStore.read<List<dynamic>>(
        _allNamesCacheKey,
        (json) => json['list'] as List<dynamic>,
      );
      if (cachedRaw != null && !cachedRaw.isStale(_staticCacheTtl))
        return Success(getCachedAllNames()!);
    }

    if (!await networkInfo.isConnected) {
      final cached = getCachedAllNames();
      if (cached != null) return Success(cached);
      return const Error(NetworkFailure());
    }

    try {
      final models = await remoteDataSource.getAllNames();
      await cacheStore.save<List<dynamic>>(
        _allNamesCacheKey,
        models.map((m) => m.toJson()).toList(),
        (list) => {'list': list},
      );
      return Success(models.map((m) => m.toEntity()).toList());
    } on ServerException catch (e) {
      final cached = getCachedAllNames();
      if (cached != null) return Success(cached);
      return Error(
        ServerFailure(
          e.message ?? 'Something went wrong on our end. Try again.',
        ),
      );
    } catch (e, stackTrace) {
      AppLogger.e(
        'AsmaUlHusnaRepository: unexpected error (all names)',
        e,
        stackTrace,
      );
      return const Error(UnexpectedFailure());
    }
  }

  @override
  Future<Result<AsmaDaily>> fetchDailyNames(
    int dayNumber, {
    bool forceRefresh = false,
  }) async {
    final key = _dailyCacheKey(dayNumber);

    if (!forceRefresh) {
      final cached = cacheStore.read(key, AsmaDailyModel.fromJson);
      if (cached != null && !cached.isStale(_staticCacheTtl))
        return Success(cached.data.toEntity());
    }

    if (!await networkInfo.isConnected) {
      final cached = cacheStore.read(key, AsmaDailyModel.fromJson);
      if (cached != null) return Success(cached.data.toEntity());
      return const Error(NetworkFailure());
    }

    try {
      final model = await remoteDataSource.getDailyNames(dayNumber);
      await cacheStore.save(key, model, (m) => m.toJson());
      return Success(model.toEntity());
    } on ServerException catch (e) {
      final cached = cacheStore.read(key, AsmaDailyModel.fromJson);
      if (cached != null) return Success(cached.data.toEntity());
      return Error(
        ServerFailure(
          e.message ?? 'Something went wrong on our end. Try again.',
        ),
      );
    } catch (e, stackTrace) {
      AppLogger.e(
        'AsmaUlHusnaRepository: unexpected error (daily)',
        e,
        stackTrace,
      );
      return const Error(UnexpectedFailure());
    }
  }

  @override
  Future<Result<List<AsmaName>>> search(String query) async {
    final key = _searchCacheKey(query);
    final cachedRaw = cacheStore.read<List<dynamic>>(
      key,
      (json) => json['list'] as List<dynamic>,
    );
    if (cachedRaw != null && !cachedRaw.isStale(_searchCacheTtl)) {
      return Success(
        cachedRaw.data
            .map(
              (e) =>
                  AsmaNameModel.fromJson(e as Map<String, dynamic>).toEntity(),
            )
            .toList(),
      );
    }

    if (!await networkInfo.isConnected) {
      if (cachedRaw != null) {
        return Success(
          cachedRaw.data
              .map(
                (e) => AsmaNameModel.fromJson(
                  e as Map<String, dynamic>,
                ).toEntity(),
              )
              .toList(),
        );
      }
      return const Error(NetworkFailure());
    }

    try {
      final models = await remoteDataSource.search(query);
      await cacheStore.save<List<dynamic>>(
        key,
        models.map((m) => m.toJson()).toList(),
        (list) => {'list': list},
      );
      return Success(models.map((m) => m.toEntity()).toList());
    } on ServerException catch (e) {
      if (cachedRaw != null) {
        return Success(
          cachedRaw.data
              .map(
                (e) => AsmaNameModel.fromJson(
                  e as Map<String, dynamic>,
                ).toEntity(),
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
      AppLogger.e(
        'AsmaUlHusnaRepository: unexpected error (search)',
        e,
        stackTrace,
      );
      return const Error(UnexpectedFailure());
    }
  }
}
