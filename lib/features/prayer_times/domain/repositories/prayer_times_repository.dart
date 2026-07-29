import '../../../../core/usecase/usecase.dart';
import '../entities/prayer_times.dart';

abstract class PrayerTimesRepository {
  /// Synchronous read of whatever was last cached for the last known
  /// location. Returns null if nothing has been cached yet.
  PrayerTimes? getCachedPrayerTimesForLastKnownLocation();

  /// Resolves the current location, fetches fresh prayer times from the
  /// network using the given calculation [method] and Asr [school], and
  /// caches the result. [forceRefresh] is reserved for future cache-
  /// freshness checks; currently every call hits the network.
  Future<Result<PrayerTimes>> fetchAndCachePrayerTimes({
    required int method,
    required int school,
    bool forceRefresh = false,
  });

  /// Every day's prayer times for a given Gregorian month, for the
  /// Prayer Calendar screen. Not cached (visited far less often than
  /// today's times, and caching every month indefinitely would grow
  /// storage unbounded) — always hits the network.
  Future<Result<List<PrayerTimes>>> fetchMonthCalendar({
    required int year,
    required int month,
    required int method,
    required int school,
  });
}
