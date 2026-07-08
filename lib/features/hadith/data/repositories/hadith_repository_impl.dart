import '../../../../core/cache/hive_cache_store.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../../core/utils/logger.dart';
import '../../domain/entities/hadith.dart';
import '../../domain/entities/hadith_collection.dart';
import '../../domain/repositories/hadith_repository.dart';
import '../datasources/hadith_remote_datasource.dart';
import '../models/daily_hadith_cache_model.dart';
import '../models/hadith_collection_model.dart';
import '../models/hadith_list_page_model.dart';
import '../models/hadith_model.dart';

class HadithRepositoryImpl implements HadithRepository {
  final HadithRemoteDataSource remoteDataSource;
  final HiveCacheStore cacheStore;
  final NetworkInfo networkInfo;

  const HadithRepositoryImpl({
    required this.remoteDataSource,
    required this.cacheStore,
    required this.networkInfo,
  });

  static const _collectionsCacheKey = 'hadith_collections';
  static const _collectionsCacheTtl = Duration(
    days: 30,
  ); // this list never changes
  static const _pageCacheTtl = Duration(days: 30); // hadith text is static
  static const _dailyHadithCacheKey = 'hadith_daily';
  static const _searchCacheTtl = Duration(hours: 1);

  String _pageCacheKey(String collection, int page) =>
      'hadith_page_${collection}_$page';
  String _searchCacheKey(String query, String? collection, int limit) =>
      'hadith_search_${query.toLowerCase()}_${collection ?? 'all'}_$limit';

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  @override
  List<HadithCollection>? getCachedCollections() {
    final cached = cacheStore.read<List<dynamic>>(
      _collectionsCacheKey,
      (json) => json['list'] as List<dynamic>,
    );
    return cached?.data
        .map(
          (e) => HadithCollectionModel.fromJson(
            e as Map<String, dynamic>,
          ).toEntity(),
        )
        .toList();
  }

  @override
  Future<Result<List<HadithCollection>>> fetchAndCacheCollections({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      final cachedRaw = cacheStore.read<List<dynamic>>(
        _collectionsCacheKey,
        (json) => json['list'] as List<dynamic>,
      );
      if (cachedRaw != null && !cachedRaw.isStale(_collectionsCacheTtl)) {
        return Success(getCachedCollections()!);
      }
    }

    if (!await networkInfo.isConnected) {
      final cached = getCachedCollections();
      if (cached != null) return Success(cached);
      return const Error(NetworkFailure());
    }

    try {
      final models = await remoteDataSource.getCollections();
      await cacheStore.save<List<dynamic>>(
        _collectionsCacheKey,
        models.map((m) => m.toJson()).toList(),
        (list) => {'list': list},
      );
      return Success(models.map((m) => m.toEntity()).toList());
    } on ServerException catch (e) {
      final cached = getCachedCollections();
      if (cached != null) return Success(cached);
      return Error(
        ServerFailure(
          e.message ?? 'Something went wrong on our end. Try again.',
        ),
      );
    } catch (e, stackTrace) {
      AppLogger.e(
        'HadithRepository: unexpected error (collections)',
        e,
        stackTrace,
      );
      return const Error(UnexpectedFailure());
    }
  }

  @override
  Future<Result<HadithPageResult>> fetchAndCacheHadithPage(
    String collection,
    int page, {
    bool forceRefresh = false,
  }) async {
    final key = _pageCacheKey(collection, page);

    if (!forceRefresh) {
      final cached = cacheStore.read(key, HadithListPageModel.fromJson);
      if (cached != null && !cached.isStale(_pageCacheTtl)) {
        return Success(
          HadithPageResult(
            hadiths: cached.data.hadiths.map((h) => h.toEntity()).toList(),
            page: cached.data.page,
            totalPages: cached.data.totalPages,
          ),
        );
      }
    }

    if (!await networkInfo.isConnected) {
      final cached = cacheStore.read(key, HadithListPageModel.fromJson);
      if (cached != null) {
        return Success(
          HadithPageResult(
            hadiths: cached.data.hadiths.map((h) => h.toEntity()).toList(),
            page: cached.data.page,
            totalPages: cached.data.totalPages,
          ),
        );
      }
      return const Error(NetworkFailure());
    }

    try {
      final model = await remoteDataSource.getHadithPage(collection, page);
      await cacheStore.save(key, model, (m) => m.toJson());
      return Success(
        HadithPageResult(
          hadiths: model.hadiths.map((h) => h.toEntity()).toList(),
          page: model.page,
          totalPages: model.totalPages,
        ),
      );
    } on ServerException catch (e) {
      final cached = cacheStore.read(key, HadithListPageModel.fromJson);
      if (cached != null) {
        return Success(
          HadithPageResult(
            hadiths: cached.data.hadiths.map((h) => h.toEntity()).toList(),
            page: cached.data.page,
            totalPages: cached.data.totalPages,
          ),
        );
      }
      return Error(
        ServerFailure(
          e.message ?? 'Something went wrong on our end. Try again.',
        ),
      );
    } catch (e, stackTrace) {
      AppLogger.e('HadithRepository: unexpected error (page)', e, stackTrace);
      return const Error(UnexpectedFailure());
    }
  }

  @override
  Future<Result<Hadith>> fetchDailyHadith() async {
    final cached = cacheStore.read(
      _dailyHadithCacheKey,
      DailyHadithCacheModel.fromJson,
    );

    // Already fetched today — reuse it, no network call.
    if (cached != null && cached.data.date == _todayKey()) {
      return Success(cached.data.hadith.toEntity());
    }

    if (!await networkInfo.isConnected) {
      // Offline and it's a new day — better to show yesterday's than nothing.
      if (cached != null) return Success(cached.data.hadith.toEntity());
      return const Error(NetworkFailure());
    }

    try {
      final model = await remoteDataSource.getRandomHadith();
      final wrapper = DailyHadithCacheModel(date: _todayKey(), hadith: model);
      await cacheStore.save(_dailyHadithCacheKey, wrapper, (w) => w.toJson());
      return Success(model.toEntity());
    } on ServerException catch (e) {
      if (cached != null) return Success(cached.data.hadith.toEntity());
      return Error(
        ServerFailure(
          e.message ?? 'Something went wrong on our end. Try again.',
        ),
      );
    } catch (e, stackTrace) {
      AppLogger.e('HadithRepository: unexpected error (daily)', e, stackTrace);
      return const Error(UnexpectedFailure());
    }
  }

  @override
  Future<Result<List<Hadith>>> search(
    String query, {
    String? collection,
    int limit = 25,
  }) async {
    final key = _searchCacheKey(query, collection, limit);
    final cachedRaw = cacheStore.read<List<dynamic>>(
      key,
      (json) => json['list'] as List<dynamic>,
    );
    if (cachedRaw != null && !cachedRaw.isStale(_searchCacheTtl)) {
      return Success(
        cachedRaw.data
            .map(
              (e) => HadithModel.fromJson(e as Map<String, dynamic>).toEntity(),
            )
            .toList(),
      );
    }

    if (!await networkInfo.isConnected) {
      if (cachedRaw != null) {
        return Success(
          cachedRaw.data
              .map(
                (e) =>
                    HadithModel.fromJson(e as Map<String, dynamic>).toEntity(),
              )
              .toList(),
        );
      }
      return const Error(NetworkFailure());
    }

    try {
      final models = await remoteDataSource.search(
        query,
        collection: collection,
        limit: limit,
      );
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
                (e) =>
                    HadithModel.fromJson(e as Map<String, dynamic>).toEntity(),
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
      AppLogger.e('HadithRepository: unexpected error (search)', e, stackTrace);
      return const Error(UnexpectedFailure());
    }
  }
}
