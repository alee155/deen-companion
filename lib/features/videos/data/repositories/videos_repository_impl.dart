import '../../../../core/cache/hive_cache_store.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../../core/utils/logger.dart';
import '../../domain/entities/daily_videos.dart';
import '../../domain/repositories/videos_repository.dart';
import '../../domain/services/video_platform_registry.dart';
import '../datasources/videos_remote_datasource.dart';
import '../models/daily_videos_model.dart';

class VideosRepositoryImpl implements VideosRepository {
  final VideosRemoteDataSource remote;
  final HiveCacheStore cache;
  final VideoPlatformRegistry registry;

  /// Injected so tests can say what time it is.
  final DateTime Function() now;

  VideosRepositoryImpl({
    required this.remote,
    required this.cache,
    this.registry = const VideoPlatformRegistry(),
    DateTime Function()? now,
  }) : now = now ?? DateTime.now;

  static const _cacheKey = 'daily_bayan_videos';

  /// Always asked for the most the API gives: a smaller count is a prefix of a
  /// larger one, so one request and one saved copy serve every screen.
  static const requestCount = 10;

  DailyVideos? _read() {
    try {
      return cache
          .read(_cacheKey, (j) => dailyVideosFromJson(j, registry))
          ?.data;
    } catch (e, st) {
      AppLogger.e('VideosRepository: unreadable saved copy', e, st);
      return null;
    }
  }

  @override
  DailyVideos? getCached() {
    final saved = _read();
    return saved != null && saved.isValidAt(now()) ? saved : null;
  }

  @override
  Future<Result<DailyVideos>> getDailyVideos({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      final fresh = getCached();
      if (fresh != null) return Success(fresh);
    }
    try {
      final data = await remote.getRandom(count: requestCount);
      final daily = dailyVideosFromJson(data, registry);
      await cache.save(_cacheKey, daily, dailyVideosToJson);
      return Success(daily);
    } on NetworkException {
      return _offline(const NetworkFailure());
    } on ServerException catch (e) {
      final m = e.message;
      return _offline(m == null ? const ServerFailure() : ServerFailure(m));
    } catch (e, st) {
      AppLogger.e('VideosRepository: getDailyVideos failed', e, st);
      return _offline(const UnexpectedFailure());
    }
  }

  /// Yesterday's set is still better than an empty section.
  Result<DailyVideos> _offline(Failure failure) {
    final stale = _read();
    return stale != null && stale.videos.isNotEmpty
        ? Success(stale)
        : Error(failure);
  }
}
