import 'package:deen_companion/core/network/api_endpoints.dart';
import 'package:deen_companion/core/network/interceptors/auth_interceptor.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../features/auth/_support/auth_fakes.dart';

class _Adapter implements HttpClientAdapter {
  RequestOptions? last;
  final int status;
  _Adapter([this.status = 200]);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    last = options;
    return ResponseBody.fromString(
      '{"message":"x"}',
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Dio _dio(MemoryTokens t, _Adapter a, [void Function()? onUnauthorized]) => Dio()
  ..httpClientAdapter = a
  ..interceptors.add(AuthInterceptor(t, onUnauthorized: onUnauthorized));

void main() {
  test('adds the bearer token for the Deen backend only', () async {
    final a = _Adapter();
    final dio = _dio(MemoryTokens(access: 'abc'), a);
    await dio.get(ApiEndpoints.authMe);
    expect(a.last!.headers['Authorization'], 'Bearer abc');
    await dio.get('https://ummahapi.com/api/qibla');
    expect(a.last!.headers.containsKey('Authorization'), isFalse);
  });

  test('never sends the pending (unverified) token', () async {
    final a = _Adapter();
    await _dio(MemoryTokens(pending: 'p'), a).post(ApiEndpoints.authRegister);
    expect(a.last!.headers.containsKey('Authorization'), isFalse);
  });

  test('401 with a token clears it and signals the session', () async {
    final tokens = MemoryTokens(access: 'old');
    var fired = 0;
    final dio = _dio(tokens, _Adapter(401), () => fired++);
    await expectLater(
      dio.get(ApiEndpoints.authMe),
      throwsA(isA<DioException>()),
    );
    expect(fired, 1);
    expect(tokens.access, isNull);
  });

  test(
    '401 from login/register (bad credentials) is not a dead session',
    () async {
      final tokens = MemoryTokens(access: 'keep');
      var fired = 0;
      final dio = _dio(tokens, _Adapter(401), () => fired++);
      await expectLater(
        dio.post(ApiEndpoints.authLogin),
        throwsA(isA<DioException>()),
      );
      expect(fired, 0);
      expect(tokens.access, 'keep');
    },
  );

  test('401 without a token (guest) does nothing', () async {
    var fired = 0;
    final dio = _dio(MemoryTokens(), _Adapter(401), () => fired++);
    await expectLater(
      dio.get(ApiEndpoints.authMe),
      throwsA(isA<DioException>()),
    );
    expect(fired, 0);
  });

  test('other errors (500) keep the session', () async {
    final tokens = MemoryTokens(access: 'keep');
    var fired = 0;
    final dio = _dio(tokens, _Adapter(500), () => fired++);
    await expectLater(
      dio.get(ApiEndpoints.authMe),
      throwsA(isA<DioException>()),
    );
    expect(fired, 0);
    expect(tokens.access, 'keep');
  });
}
