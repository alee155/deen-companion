import '../../../../core/cache/hive_cache_store.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../../core/utils/logger.dart';
import '../../domain/entities/quran_meta.dart';
import '../../domain/entities/surah_summary.dart';
import '../../domain/entities/juz.dart';
import '../../domain/entities/mushaf_page.dart';
import '../../domain/entities/search_result.dart';
import '../../domain/repositories/quran_repository.dart';
import '../datasources/quran_remote_datasource.dart';
import '../models/quran_meta_model.dart';
import '../models/surah_summary_model.dart';
import '../models/juz_model.dart';
import '../models/mushaf_page_model.dart';
import '../models/search_result_model.dart';

class QuranRepositoryImpl implements QuranRepository {
  final QuranRemoteDataSource remoteDataSource;
  final HiveCacheStore cacheStore;
  final NetworkInfo networkInfo;

  const QuranRepositoryImpl({
    required this.remoteDataSource,
    required this.cacheStore,
    required this.networkInfo,
  });

  // ── Cache TTLs ──
  // Quran reference data (meta, surah list, juz, mushaf pages) barely
  // ever changes — long TTLs mean we skip the network on most app opens.
  // Search results are query-specific and shorter-lived.
  static const _metaCacheTtl = Duration(hours: 12);
  static const _surahListCacheTtl = Duration(hours: 12);
  static const _juzCacheTtl = Duration(days: 30);
  static const _pageCacheTtl = Duration(days: 30);
  static const _searchCacheTtl = Duration(hours: 1);

  // ── Cache keys ──
  static const _metaCacheKey = 'quran_meta';
  static const _surahListCacheKey = 'quran_surah_list';
  String _juzCacheKey(int number) => 'quran_juz_$number';
  String _pageCacheKey(int number) => 'quran_page_$number';
  String _searchCacheKey(String query, String translation, int limit) =>
      'quran_search_${query.toLowerCase()}_${translation}_$limit';

  // ─────────────────────────────────────────────
  // Quran meta
  // ─────────────────────────────────────────────

  @override
  QuranMeta? getCachedQuranMeta() {
    return cacheStore
        .read(_metaCacheKey, QuranMetaModel.fromJson)
        ?.data
        .toEntity();
  }

  @override
  Future<Result<QuranMeta>> fetchAndCacheQuranMeta({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      final cached = cacheStore.read(_metaCacheKey, QuranMetaModel.fromJson);
      if (cached != null && !cached.isStale(_metaCacheTtl)) {
        return Success(cached.data.toEntity());
      }
    }

    if (!await networkInfo.isConnected) {
      final cached = getCachedQuranMeta();
      if (cached != null) return Success(cached);
      return const Error(NetworkFailure());
    }

    try {
      final model = await remoteDataSource.getQuranMeta();
      await cacheStore.save(_metaCacheKey, model, (m) => m.toJson());
      return Success(model.toEntity());
    } on ServerException catch (e) {
      final cached = getCachedQuranMeta();
      if (cached != null) return Success(cached);
      return Error(
        ServerFailure(
          e.message ?? 'Something went wrong on our end. Try again.',
        ),
      );
    } catch (e, stackTrace) {
      AppLogger.e('QuranRepository: unexpected error (meta)', e, stackTrace);
      return const Error(UnexpectedFailure());
    }
  }

  // ─────────────────────────────────────────────
  // Surah list
  // ─────────────────────────────────────────────

  @override
  List<SurahSummary>? getCachedSurahList() {
    final cached = cacheStore.read<List<dynamic>>(
      _surahListCacheKey,
      (json) => json['list'] as List<dynamic>,
    );
    return cached?.data
        .map(
          (e) =>
              SurahSummaryModel.fromJson(e as Map<String, dynamic>).toEntity(),
        )
        .toList();
  }

  @override
  Future<Result<List<SurahSummary>>> fetchAndCacheSurahList({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      final cachedRaw = cacheStore.read<List<dynamic>>(
        _surahListCacheKey,
        (json) => json['list'] as List<dynamic>,
      );
      if (cachedRaw != null && !cachedRaw.isStale(_surahListCacheTtl)) {
        return Success(getCachedSurahList()!);
      }
    }

    if (!await networkInfo.isConnected) {
      final cached = getCachedSurahList();
      if (cached != null) return Success(cached);
      return const Error(NetworkFailure());
    }

    try {
      final models = await remoteDataSource.getSurahList();
      await cacheStore.save<List<dynamic>>(
        _surahListCacheKey,
        models.map((m) => m.toJson()).toList(),
        (list) => {'list': list},
      );
      return Success(models.map((m) => m.toEntity()).toList());
    } on ServerException catch (e) {
      final cached = getCachedSurahList();
      if (cached != null) return Success(cached);
      return Error(
        ServerFailure(
          e.message ?? 'Something went wrong on our end. Try again.',
        ),
      );
    } catch (e, stackTrace) {
      AppLogger.e(
        'QuranRepository: unexpected error (surah list)',
        e,
        stackTrace,
      );
      return const Error(UnexpectedFailure());
    }
  }

  // ─────────────────────────────────────────────
  // Juz
  // ─────────────────────────────────────────────

  @override
  Juz? getCachedJuz(int number) {
    return cacheStore
        .read(_juzCacheKey(number), JuzModel.fromJson)
        ?.data
        .toEntity();
  }

  @override
  Future<Result<Juz>> fetchAndCacheJuz(
    int number, {
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      final cached = cacheStore.read(_juzCacheKey(number), JuzModel.fromJson);
      if (cached != null && !cached.isStale(_juzCacheTtl)) {
        return Success(cached.data.toEntity());
      }
    }

    if (!await networkInfo.isConnected) {
      final cached = getCachedJuz(number);
      if (cached != null) return Success(cached);
      return const Error(NetworkFailure());
    }

    try {
      final model = await remoteDataSource.getJuz(number);
      await cacheStore.save(_juzCacheKey(number), model, (m) => m.toJson());
      return Success(model.toEntity());
    } on ServerException catch (e) {
      final cached = getCachedJuz(number);
      if (cached != null) return Success(cached);
      return Error(
        ServerFailure(
          e.message ?? 'Something went wrong on our end. Try again.',
        ),
      );
    } catch (e, stackTrace) {
      AppLogger.e('QuranRepository: unexpected error (juz)', e, stackTrace);
      return const Error(UnexpectedFailure());
    }
  }

  // ─────────────────────────────────────────────
  // Mushaf page
  // ─────────────────────────────────────────────

  @override
  MushafPage? getCachedMushafPage(int number) {
    return cacheStore
        .read(_pageCacheKey(number), MushafPageModel.fromJson)
        ?.data
        .toEntity();
  }

  @override
  Future<Result<MushafPage>> fetchAndCacheMushafPage(
    int number, {
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      final cached = cacheStore.read(
        _pageCacheKey(number),
        MushafPageModel.fromJson,
      );
      if (cached != null && !cached.isStale(_pageCacheTtl)) {
        return Success(cached.data.toEntity());
      }
    }

    if (!await networkInfo.isConnected) {
      final cached = getCachedMushafPage(number);
      if (cached != null) return Success(cached);
      return const Error(NetworkFailure());
    }

    try {
      final model = await remoteDataSource.getMushafPage(number);
      await cacheStore.save(_pageCacheKey(number), model, (m) => m.toJson());
      return Success(model.toEntity());
    } on ServerException catch (e) {
      final cached = getCachedMushafPage(number);
      if (cached != null) return Success(cached);
      return Error(
        ServerFailure(
          e.message ?? 'Something went wrong on our end. Try again.',
        ),
      );
    } catch (e, stackTrace) {
      AppLogger.e('QuranRepository: unexpected error (page)', e, stackTrace);
      return const Error(UnexpectedFailure());
    }
  }

  // ─────────────────────────────────────────────
  // Search
  // ─────────────────────────────────────────────

  @override
  List<SearchResult>? getCachedSearchResults(
    String query, {
    String translation = 'sahih_international',
    int limit = 25,
  }) {
    final key = _searchCacheKey(query, translation, limit);
    final cached = cacheStore.read<List<dynamic>>(
      key,
      (json) => json['list'] as List<dynamic>,
    );
    return cached?.data
        .map(
          (e) =>
              SearchResultModel.fromJson(e as Map<String, dynamic>).toEntity(),
        )
        .toList();
  }

  @override
  Future<Result<List<SearchResult>>> search(
    String query, {
    String translation = 'sahih_international',
    int limit = 25,
    bool forceRefresh = false,
  }) async {
    final key = _searchCacheKey(query, translation, limit);

    if (!forceRefresh) {
      final cachedRaw = cacheStore.read<List<dynamic>>(
        key,
        (json) => json['list'] as List<dynamic>,
      );
      if (cachedRaw != null && !cachedRaw.isStale(_searchCacheTtl)) {
        return Success(
          getCachedSearchResults(
            query,
            translation: translation,
            limit: limit,
          )!,
        );
      }
    }

    if (!await networkInfo.isConnected) {
      final cached = getCachedSearchResults(
        query,
        translation: translation,
        limit: limit,
      );
      if (cached != null) return Success(cached);
      return const Error(NetworkFailure());
    }

    try {
      final response = await remoteDataSource.searchQuran(
        query,
        translation: translation,
        limit: limit,
      );
      await cacheStore.save<List<dynamic>>(
        key,
        response.results.map((r) => r.toJson()).toList(),
        (list) => {'list': list},
      );
      return Success(response.results.map((r) => r.toEntity()).toList());
    } on ServerException catch (e) {
      final cached = getCachedSearchResults(
        query,
        translation: translation,
        limit: limit,
      );
      if (cached != null) return Success(cached);
      return Error(
        ServerFailure(
          e.message ?? 'Something went wrong on our end. Try again.',
        ),
      );
    } catch (e, stackTrace) {
      AppLogger.e('QuranRepository: unexpected error (search)', e, stackTrace);
      return const Error(UnexpectedFailure());
    }
  }
}
