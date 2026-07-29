import 'package:deen_companion/features/mutashabihat/data/models/mutashabihat_entry_model.dart';

import '../../../../core/cache/hive_cache_store.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../../core/utils/logger.dart';
import '../../domain/entities/mutashabihat_entry.dart';
import '../../domain/entities/mutashabihat_info.dart';
import '../../domain/entities/mutashabihat_surah_page.dart';
import '../../domain/repositories/mutashabihat_repository.dart';
import '../datasources/mutashabihat_remote_datasource.dart';
import '../models/mutashabihat_info_model.dart';
import '../models/mutashabihat_surah_page_model.dart';

class MutashabihatRepositoryImpl implements MutashabihatRepository {
  final MutashabihatRemoteDataSource remoteDataSource;
  final HiveCacheStore cacheStore;
  final NetworkInfo networkInfo;

  const MutashabihatRepositoryImpl({
    required this.remoteDataSource,
    required this.cacheStore,
    required this.networkInfo,
  });

  static const _infoCacheKey = 'mutashabihat_info';
  static const _staticCacheTtl = Duration(days: 90);

  String _ayahCacheKey(int surah, int ayah) =>
      'mutashabihat_ayah_${surah}_$ayah';
  String _surahPageCacheKey(int surah, int page) =>
      'mutashabihat_surah_${surah}_page_$page';

  @override
  MutashabihatInfo? getCachedInfo() {
    return cacheStore
        .read(_infoCacheKey, MutashabihatInfoModel.fromJson)
        ?.data
        .toEntity();
  }

  @override
  Future<Result<MutashabihatInfo>> fetchAndCacheInfo({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      final cached = cacheStore.read(
        _infoCacheKey,
        MutashabihatInfoModel.fromJson,
      );
      if (cached != null && !cached.isStale(_staticCacheTtl))
        return Success(cached.data.toEntity());
    }

    if (!await networkInfo.isConnected) {
      final cached = getCachedInfo();
      if (cached != null) return Success(cached);
      return const Error(NetworkFailure());
    }

    try {
      final model = await remoteDataSource.getInfo();
      await cacheStore.save(_infoCacheKey, model, (m) => m.toJson());
      return Success(model.toEntity());
    } on ServerException catch (e) {
      final cached = getCachedInfo();
      if (cached != null) return Success(cached);
      return Error(
        ServerFailure(
          e.message ?? 'Something went wrong on our end. Try again.',
        ),
      );
    } catch (e, stackTrace) {
      AppLogger.e(
        'MutashabihatRepository: unexpected error (info)',
        e,
        stackTrace,
      );
      return const Error(UnexpectedFailure());
    }
  }

  @override
  Future<Result<MutashabihatEntry>> fetchRandom() async {
    // Deliberately not cached — the whole point is a fresh random pair each time.
    if (!await networkInfo.isConnected) return const Error(NetworkFailure());

    try {
      final model = await remoteDataSource.getRandom();
      return Success(model.toEntity());
    } on ServerException catch (e) {
      return Error(
        ServerFailure(
          e.message ?? 'Something went wrong on our end. Try again.',
        ),
      );
    } catch (e, stackTrace) {
      AppLogger.e(
        'MutashabihatRepository: unexpected error (random)',
        e,
        stackTrace,
      );
      return const Error(UnexpectedFailure());
    }
  }

  @override
  Future<Result<MutashabihatEntry>> fetchByAyah(int surah, int ayah) async {
    final key = _ayahCacheKey(surah, ayah);

    final cached = cacheStore.read(key, (json) => json);
    // Reuse the entry model's fromJson through the generic cache path below
    // rather than duplicating — see the try block for the real read.

    if (!await networkInfo.isConnected) {
      final cachedEntry = cacheStore.read(key, _entryFromJson);
      if (cachedEntry != null) return Success(cachedEntry.data);
      return const Error(NetworkFailure());
    }

    try {
      final model = await remoteDataSource.getByAyah(surah, ayah);
      await cacheStore.save(key, model, (m) => m.toJson());
      return Success(model.toEntity());
    } on NotFoundException {
      return const Error(
        NotFoundFailure('No similar verses are known for this ayah.'),
      );
    } on ServerException catch (e) {
      final cachedEntry = cacheStore.read(key, _entryFromJson);
      if (cachedEntry != null) return Success(cachedEntry.data);
      return Error(
        ServerFailure(
          e.message ?? 'Something went wrong on our end. Try again.',
        ),
      );
    } catch (e, stackTrace) {
      AppLogger.e(
        'MutashabihatRepository: unexpected error (by ayah)',
        e,
        stackTrace,
      );
      return const Error(UnexpectedFailure());
    }
  }

  MutashabihatEntry _entryFromJson(Map<String, dynamic> json) {
    return MutashabihatEntryModel.fromJson(json).toEntity();
  }

  @override
  Future<Result<MutashabihatSurahPage>> fetchSurahPage(
    int surah,
    int page, {
    bool forceRefresh = false,
  }) async {
    final key = _surahPageCacheKey(surah, page);

    if (!forceRefresh) {
      final cached = cacheStore.read(key, MutashabihatSurahPageModel.fromJson);
      if (cached != null && !cached.isStale(_staticCacheTtl))
        return Success(cached.data.toEntity());
    }

    if (!await networkInfo.isConnected) {
      final cached = cacheStore.read(key, MutashabihatSurahPageModel.fromJson);
      if (cached != null) return Success(cached.data.toEntity());
      return const Error(NetworkFailure());
    }

    try {
      final model = await remoteDataSource.getSurahPage(surah, page);
      await cacheStore.save(key, model, (m) => m.toJson());
      return Success(model.toEntity());
    } on ServerException catch (e) {
      final cached = cacheStore.read(key, MutashabihatSurahPageModel.fromJson);
      if (cached != null) return Success(cached.data.toEntity());
      return Error(
        ServerFailure(
          e.message ?? 'Something went wrong on our end. Try again.',
        ),
      );
    } catch (e, stackTrace) {
      AppLogger.e(
        'MutashabihatRepository: unexpected error (surah page)',
        e,
        stackTrace,
      );
      return const Error(UnexpectedFailure());
    }
  }
}
