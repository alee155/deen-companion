/// Wraps any cached value with when it was fetched, so callers can
/// decide whether it's still fresh enough to skip a network call.
class CachedResult<T> {
  final T data;
  final DateTime fetchedAt;

  const CachedResult({required this.data, required this.fetchedAt});

  bool isStale(Duration maxAge) =>
      DateTime.now().difference(fetchedAt) > maxAge;
}
