import 'package:deen_companion/core/cache/cached_result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fresh entry is not stale', () {
    final r = CachedResult(data: 1, fetchedAt: DateTime.now());
    expect(r.isStale(const Duration(hours: 1)), isFalse);
  });

  test('old entry is stale', () {
    final r = CachedResult(
      data: 'x',
      fetchedAt: DateTime.now().subtract(const Duration(hours: 2)),
    );
    expect(r.isStale(const Duration(hours: 1)), isTrue);
    expect(r.isStale(const Duration(hours: 3)), isFalse);
  });

  test('zero maxAge makes any past entry stale', () {
    final r = CachedResult(
      data: 1,
      fetchedAt: DateTime.now().subtract(const Duration(milliseconds: 5)),
    );
    expect(r.isStale(Duration.zero), isTrue);
  });
}
