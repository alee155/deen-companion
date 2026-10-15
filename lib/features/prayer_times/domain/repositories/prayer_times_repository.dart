import '../../../../core/location/location_service.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/prayer_times.dart';
import '../entities/prayer_times_bundle.dart';

/// Prayer times as the Deen backend serves them. The backend calculates and
/// stores the times; the app sends a location (and, rarely, a method and
/// school) and displays what comes back. Signed-in users and guests use
/// different endpoints with the same response shape.
abstract class PrayerTimesRepository {
  /// Whatever was last cached, readable synchronously for cache-first
  /// screens. Null until a first successful fetch.
  PrayerTimesBundle? getCachedBundle();

  /// Today's times from the cache (see [getCachedBundle]).
  PrayerTimes? getCachedToday(DateTime now);

  // ── Guests (no token; the device id is the rate-limit key) ──────────────

  /// `GET /prayer-times` — [days] 1 to 31. Caches the result.
  Future<Result<PrayerTimesBundle>> fetchGuestTimes(
    Coordinates coordinates, {
    int? method,
    int? school,
    int days = 31,
  });

  /// `GET /prayer-times/month`.
  Future<Result<PrayerTimesBundle>> fetchGuestMonth(
    Coordinates coordinates, {
    required int year,
    required int month,
    int? method,
    int? school,
  });

  // ── Signed in ───────────────────────────────────────────────────────────

  /// `GET /prayers/location` — what the account has saved.
  Future<Result<SavedPrayerSettings>> getSavedSettings();

  /// `PUT /prayers/location`. Omit [method]/[school] to keep the saved
  /// choice. Caches the returned days.
  Future<Result<PrayerTimesBundle>> putLocation(
    Coordinates coordinates, {
    int? method,
    int? school,
  });

  /// `GET /prayers/times` — [days] 1 to 31. Caches the result.
  Future<Result<PrayerTimesBundle>> fetchAccountTimes({int days = 31});

  /// `GET /prayers/times/month`.
  Future<Result<PrayerTimesBundle>> fetchAccountMonth({
    required int year,
    required int month,
  });

  /// `DELETE /prayers/location` — also drops the local cache.
  Future<Result<void>> clearAccountLocation();

  // ── Both ────────────────────────────────────────────────────────────────

  /// `GET /prayer-times/cities` — English names work best.
  Future<Result<List<PrayerCity>>> searchCities(String query);

  /// `GET /prayer-times/methods` — never hard-code the list.
  Future<Result<List<CalculationMethodOption>>> getMethods();

  /// Forgets cached days and months (sign-out, location cleared).
  Future<void> clearCache();
}
