import 'dart:typed_data';

import 'package:deen_companion/core/connectivity/data/connectivity_interceptor.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Answers with a fixed result, or fails the way a dead network does.
class _Adapter implements HttpClientAdapter {
  final int? status;
  final DioExceptionType? failure;
  _Adapter.status(this.status) : failure = null;
  _Adapter.fail(this.failure) : status = null;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (failure != null) {
      throw DioException(requestOptions: options, type: failure!);
    }
    return ResponseBody.fromString('{}', status!);
  }
}

void main() {
  late int reachable;
  late int unreachable;

  Dio dio(HttpClientAdapter adapter) {
    reachable = 0;
    unreachable = 0;
    return Dio()
      ..httpClientAdapter = adapter
      ..interceptors.add(
        ConnectivityInterceptor(
          onReachable: () => reachable++,
          onUnreachable: () => unreachable++,
        ),
      );
  }

  test('a normal response proves the connection works', () async {
    await dio(_Adapter.status(200)).get('https://x.test/a');
    expect((reachable, unreachable), (1, 0));
  });

  for (final code in [400, 401, 404, 500, 503]) {
    test(
      'an error response ($code) still proves it: the server answered',
      () async {
        final d = dio(_Adapter.status(code));
        await expectLater(
          d.get('https://x.test/a'),
          throwsA(isA<DioException>()),
        );
        expect((reachable, unreachable), (1, 0));
      },
    );
  }

  for (final type in [
    DioExceptionType.connectionError,
    DioExceptionType.connectionTimeout,
    DioExceptionType.sendTimeout,
    DioExceptionType.receiveTimeout,
  ]) {
    test('${type.name} is a sign the connection is down', () async {
      final d = dio(_Adapter.fail(type));
      await expectLater(
        d.get('https://x.test/a'),
        throwsA(isA<DioException>()),
      );
      expect((reachable, unreachable), (0, 1));
    });
  }

  test('a cancelled request says nothing either way', () async {
    final d = dio(_Adapter.fail(DioExceptionType.cancel));
    await expectLater(d.get('https://x.test/a'), throwsA(isA<DioException>()));
    expect((reachable, unreachable), (0, 0));
  });

  test('the original error still reaches the caller untouched', () async {
    final d = dio(_Adapter.fail(DioExceptionType.connectionError));
    await expectLater(
      d.get('https://x.test/a'),
      throwsA(
        isA<DioException>().having(
          (e) => e.type,
          'type',
          DioExceptionType.connectionError,
        ),
      ),
    );
  });
}
