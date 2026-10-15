import '../../../core/error/failures.dart';

/// Backend error codes the prayer-times flow reacts to. Anything else is
/// [other]; the message still reaches the user.
enum PrayerTimesErrorCode {
  /// 409 — the account has no saved location yet.
  locationNotSet('LOCATION_NOT_SET'),

  /// 503 — the provider is down and nothing is cached server-side.
  providerUnavailable('PRAYER_PROVIDER_UNAVAILABLE'),

  /// 503 — calculated times failed the server's sanity checks.
  timesInvalid('PRAYER_TIMES_INVALID'),

  /// 503 — the city search provider is down.
  citySearchUnavailable('CITY_SEARCH_UNAVAILABLE'),

  /// 429 — too many requests; back off.
  rateLimited(''),
  other('');

  final String wire;
  const PrayerTimesErrorCode(this.wire);

  static PrayerTimesErrorCode parse(String? code, int? statusCode) {
    for (final c in values) {
      if (c.wire.isNotEmpty && c.wire == code) return c;
    }
    return statusCode == 429 ? rateLimited : other;
  }
}

/// A server error on a prayer-times endpoint, keeping the [code] so callers
/// can pick the right recovery (ask for a location, retry later, …).
class PrayerTimesFailure extends ServerFailure {
  final PrayerTimesErrorCode code;
  final int? statusCode;

  const PrayerTimesFailure(
    super.message, {
    this.code = PrayerTimesErrorCode.other,
    this.statusCode,
  });
}
