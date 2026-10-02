import 'package:deen_companion/core/error/exceptions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('exceptions carry optional message and are Exceptions', () {
    expect(const ServerException().message, isNull);
    expect(const ServerException('s').message, 's');
    expect(const CacheException('c').message, 'c');
    expect(const NetworkException('n').message, 'n');
    expect(const NotFoundException('f').message, 'f');
    expect(const CacheException(), isA<Exception>());
  });

  test('can be thrown and caught by type', () {
    expect(
      () => throw const NotFoundException('x'),
      throwsA(isA<NotFoundException>()),
    );
    expect(
      () => throw const NetworkException(),
      isNot(throwsA(isA<ServerException>())),
    );
  });
}
