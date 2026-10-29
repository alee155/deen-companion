import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/cache/cache_first_stream_notifier.dart';
import '../../../../core/cache/hive_cache_store.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/usecase/usecase.dart';
import '../../data/datasources/videos_remote_datasource.dart';
import '../../data/repositories/videos_repository_impl.dart';
import '../../domain/entities/bayan_video.dart';
import '../../domain/entities/daily_videos.dart';
import '../../domain/repositories/videos_repository.dart';
import '../../domain/services/video_platform_registry.dart';

/// Which platforms are known, and how each is played. Override to add one.
final videoPlatformRegistryProvider = Provider<VideoPlatformRegistry>(
  (ref) => const VideoPlatformRegistry(),
);

final videosRemoteDataSourceProvider = Provider<VideosRemoteDataSource>(
  (ref) => VideosRemoteDataSourceImpl(ref.watch(dioProvider)),
);

final videosRepositoryProvider = Provider<VideosRepository>(
  (ref) => VideosRepositoryImpl(
    remote: ref.watch(videosRemoteDataSourceProvider),
    cache: ref.watch(hiveCacheStoreProvider),
    registry: ref.watch(videoPlatformRegistryProvider),
  ),
);

/// Today's videos: the saved copy at once while it is still today's, a request
/// only when it isn't, and a fresh look at midnight when the set changes.
class DailyVideosNotifier extends CacheFirstStreamNotifier<DailyVideos> {
  VideosRepository get _repo => ref.read(videosRepositoryProvider);

  @override
  DailyVideos? readCache() => _repo.getCached();

  @override
  Future<Result<DailyVideos>> fetchFresh() async {
    final result = await _repo.getDailyVideos();
    if (result case Success(:final data)) _refreshAtMidnight(data);
    return result;
  }

  /// The set changes at [DailyVideos.validUntil]: read again then, so a day
  /// left open doesn't keep showing yesterday's talks.
  void _refreshAtMidnight(DailyVideos daily) {
    final wait = daily.validUntil.difference(DateTime.now().toUtc());
    if (wait <= Duration.zero) return;
    final timer = Timer(wait + const Duration(seconds: 5), ref.invalidateSelf);
    ref.onDispose(timer.cancel);
  }
}

final dailyVideosProvider =
    StreamNotifierProvider<DailyVideosNotifier, DailyVideos>(
      DailyVideosNotifier.new,
    );

/// One video of today's set, by its id (null if it isn't there).
final videoByIdProvider = Provider.family<BayanVideo?, String>(
  (ref, id) => ref.watch(dailyVideosProvider).valueOrNull?.byId(id),
);
