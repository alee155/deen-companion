import 'package:deen_companion/core/error/failures.dart';
import 'package:deen_companion/core/location/location_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('default messages are user-friendly and non-empty', () {
    final failures = <Failure>[
      const ServerFailure(),
      const NetworkFailure(),
      const CacheFailure(),
      const NotFoundFailure(),
      const UnexpectedFailure(),
      const NotImplementedFailure(),
    ];
    for (final f in failures) {
      expect(f.message, isNotEmpty);
      expect(f.toString(), f.message);
    }
    // Each default is distinct so the UI can tell them apart.
    expect(failures.map((f) => f.message).toSet().length, failures.length);
  });

  test('custom message overrides default', () {
    expect(const ServerFailure('boom').message, 'boom');
    expect(const NetworkFailure('x').toString(), 'x');
  });

  group('LocationFailure', () {
    test('defaults to unavailable with its user message', () {
      final f = LocationFailure();
      expect(f.kind, LocationErrorKind.unavailable);
      expect(f.message, LocationErrorKind.unavailable.userMessage);
    });

    test('uses kind message unless one is supplied', () {
      for (final kind in LocationErrorKind.values) {
        expect(LocationFailure(kind).message, kind.userMessage);
      }
      expect(
        LocationFailure(LocationErrorKind.timeout, 'custom').message,
        'custom',
      );
    });
  });

  test('sealed Failure supports exhaustive switch', () {
    String describe(Failure f) => switch (f) {
      ServerFailure() => 'server',
      NetworkFailure() => 'network',
      CacheFailure() => 'cache',
      NotFoundFailure() => 'notfound',
      UnexpectedFailure() => 'unexpected',
      NotImplementedFailure() => 'notimpl',
      LocationFailure() => 'location',
    };
    expect(describe(const CacheFailure()), 'cache');
    expect(describe(LocationFailure()), 'location');
  });
}
