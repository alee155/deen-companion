import 'dart:async';

import 'package:dio/dio.dart';
import 'package:dio_smart_retry/dio_smart_retry.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../connectivity/data/connectivity_interceptor.dart';
import '../connectivity/presentation/providers/connectivity_providers.dart';
import '../constants/app_constants.dart';
import '../config/flavor_config.dart';
import '../storage/token_storage.dart';
import 'interceptors/api_key_interceptor.dart';
import 'session_events.dart';
import 'interceptors/auth_interceptor.dart';
import 'interceptors/logging_interceptor.dart';

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(
        seconds: AppConstants.networkTimeoutSeconds,
      ),
      receiveTimeout: const Duration(
        seconds: AppConstants.networkTimeoutSeconds,
      ),
      headers: {'Content-Type': 'application/json'},
    ),
  );

  dio.interceptors.add(ApiKeyInterceptor());
  dio.interceptors.add(
    AuthInterceptor(
      ref.watch(tokenStorageProvider),
      onUnauthorized: () =>
          ref.read(unauthorizedEventProvider.notifier).state++,
    ),
  );

  // Brief network trouble shouldn't surface as an error screen: reads are
  // tried again a couple of times. Writes (uploads, logging a prayer, login)
  // are never repeated, since a retry could do the thing twice.
  dio.interceptors.add(
    RetryInterceptor(
      dio: dio,
      retries: 2,
      retryDelays: const [Duration(seconds: 1), Duration(seconds: 3)],
      retryEvaluator: _shouldRetry,
    ),
  );

  // Real requests are the best evidence about the connection: any answer
  // proves it works, repeated failures to connect prompt a check.
  dio.interceptors.add(
    ConnectivityInterceptor(
      onReachable: () =>
          ref.read(connectivityProvider.notifier).reportReachable(),
      onUnreachable: () =>
          ref.read(connectivityProvider.notifier).reportUnreachable(),
    ),
  );

  if (FlavorConfig.instance.enableLogging) {
    dio.interceptors.add(LoggingInterceptor());
  }

  return dio;
});

/// A GET that failed for a reason that may pass on its own: no connection, a
/// timeout, or the server briefly unavailable. Anything else (a 4xx, a bad
/// body, any write) is not retried.
@visibleForTesting
FutureOr<bool> shouldRetryRequest(DioException e, int attempt) =>
    _shouldRetry(e, attempt);

FutureOr<bool> _shouldRetry(DioException e, int attempt) {
  if (e.requestOptions.method != 'GET') return false;
  switch (e.type) {
    case DioExceptionType.connectionError:
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
      return true;
    case DioExceptionType.badResponse:
      final code = e.response?.statusCode;
      return code == 502 || code == 503 || code == 504;
    default:
      return false;
  }
}
