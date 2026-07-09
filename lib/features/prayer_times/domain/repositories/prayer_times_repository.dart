import '../../../../core/usecase/usecase.dart';
import '../entities/prayer_times.dart';

abstract class PrayerTimesRepository {
  /// Synchronous read of whatever was last cached for the last known
  /// location. Returns null if nothing has been cached yet.
  PrayerTimes? getCachedPrayerTimesForLastKnownLocation();

  /// Resolves the current location, fetches fresh prayer times from the
  /// network, and caches the result. [forceRefresh] is reserved for future
  /// cache-freshness checks; currently every call hits the network.
  Future<Result<PrayerTimes>> fetchAndCachePrayerTimes({
    bool forceRefresh = false,
  });
}
