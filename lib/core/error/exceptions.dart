/// Thrown by data sources (remote/local). Repositories catch these
/// and map them to Failures — exceptions never cross into domain/presentation.
class ServerException implements Exception {
  final String? message;

  /// HTTP status and the backend's machine-readable error code (e.g.
  /// `PRAYER_DAY_LOCKED`), when the response carried them.
  final int? statusCode;
  final String? code;

  /// The body's optional `data` object (e.g. `{nextPrayer, startsAt}` on a
  /// 422), so callers can show more than the message.
  final Map<String, dynamic>? data;
  const ServerException([this.message, this.statusCode, this.code, this.data]);
}

class CacheException implements Exception {
  final String? message;
  const CacheException([this.message]);
}

class NetworkException implements Exception {
  final String? message;
  const NetworkException([this.message]);
}

class NotFoundException implements Exception {
  final String? message;
  const NotFoundException([this.message]);
}
