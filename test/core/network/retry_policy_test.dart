import 'package:deen_companion/core/network/dio_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

DioException _err(DioExceptionType type, {String method = 'GET', int? status}) {
  final req = RequestOptions(path: '/x', method: method);
  return DioException(
    requestOptions: req,
    type: type,
    response: status == null
        ? null
        : Response(requestOptions: req, statusCode: status),
  );
}

void main() {
  test('a GET is retried on no connection and on timeouts', () async {
    for (final t in [
      DioExceptionType.connectionError,
      DioExceptionType.connectionTimeout,
      DioExceptionType.receiveTimeout,
    ]) {
      expect(await shouldRetryRequest(_err(t), 0), isTrue, reason: '$t');
    }
  });

  test('a GET is retried when the server is briefly unavailable', () async {
    for (final s in [502, 503, 504]) {
      expect(
        await shouldRetryRequest(
          _err(DioExceptionType.badResponse, status: s),
          0,
        ),
        isTrue,
      );
    }
  });

  test('client errors and server bugs are not retried', () async {
    for (final s in [400, 401, 403, 404, 409, 422, 500]) {
      expect(
        await shouldRetryRequest(
          _err(DioExceptionType.badResponse, status: s),
          0,
        ),
        isFalse,
        reason: '$s',
      );
    }
  });

  test('writes are never retried, even on a lost connection', () async {
    for (final m in ['POST', 'PATCH', 'PUT', 'DELETE']) {
      expect(
        await shouldRetryRequest(
          _err(DioExceptionType.connectionError, method: m),
          0,
        ),
        isFalse,
        reason: m,
      );
    }
  });
}
