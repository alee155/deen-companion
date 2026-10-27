import 'dart:typed_data';

import 'package:deen_companion/core/connectivity/data/http_reachability_probe.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class _Adapter implements HttpClientAdapter {
  final int? status;
  final DioExceptionType? failure;
  RequestOptions? last;
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
    last = options;
    if (failure != null) {
      throw DioException(requestOptions: options, type: failure!);
    }
    return ResponseBody.fromString('', status!);
  }
}

void main() {
  HttpReachabilityProbe probe(_Adapter adapter) => HttpReachabilityProbe(
    dio: Dio(BaseOptions(validateStatus: (_) => true))
      ..httpClientAdapter = adapter,
  );

  test('asks our own backend, with a HEAD request', () async {
    final adapter = _Adapter.status(200);
    await probe(adapter).canReachBackend();

    expect(adapter.last!.method, 'HEAD');
    expect(adapter.last!.uri.host, 'deencompanion.dgexpense.com');
    expect(adapter.last!.uri.scheme, 'https');
  });

  for (final code in [200, 301, 401, 404, 500, 503]) {
    test('any answer ($code) means the backend is reachable', () async {
      expect(await probe(_Adapter.status(code)).canReachBackend(), isTrue);
    });
  }

  for (final type in [
    DioExceptionType.connectionError,
    DioExceptionType.connectionTimeout,
    DioExceptionType.receiveTimeout,
  ]) {
    test('${type.name} means it is not', () async {
      expect(await probe(_Adapter.fail(type)).canReachBackend(), isFalse);
    });
  }
}
