import '../../../../core/usecase/usecase.dart';
import '../entities/daily_videos.dart';

abstract class VideosRepository {
  /// Today's set, from the saved copy while it is still today's.
  DailyVideos? getCached();

  /// `GET /videos/random`. A saved set that is still valid is returned without
  /// a request unless [forceRefresh]. Offline, an expired copy is better than
  /// nothing.
  Future<Result<DailyVideos>> getDailyVideos({bool forceRefresh = false});
}
