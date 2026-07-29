/// Thrown by data sources (remote/local). Repositories catch these
/// and map them to Failures — exceptions never cross into domain/presentation.
class ServerException implements Exception {
  final String? message;
  const ServerException([this.message]);
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
