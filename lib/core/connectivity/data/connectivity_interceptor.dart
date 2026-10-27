import 'dart:ui' show VoidCallback;

import 'package:dio/dio.dart';

/// Reports what real requests say about the connection.
///
/// A response of any kind, even a 404 or 500, proves data flows. A failure
/// to connect (or a timeout) is a hint that it doesn't. It only reports; the
/// connectivity notifier decides what that means, so one slow request never
/// flips the app offline by itself.
///
/// Callbacks rather than a provider reference, like `AuthInterceptor`, so the
/// network layer stays free of Riverpod.
class ConnectivityInterceptor extends Interceptor {
  final VoidCallback onReachable;
  final VoidCallback onUnreachable;

  ConnectivityInterceptor({
    required this.onReachable,
    required this.onUnreachable,
  });

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    onReachable();
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.response != null) {
      // The server answered (with an error): the connection is fine.
      onReachable();
    } else if (_isNetworkFailure(err.type)) {
      onUnreachable();
    }
    handler.next(err);
  }

  static bool _isNetworkFailure(DioExceptionType type) =>
      type == DioExceptionType.connectionError ||
      type == DioExceptionType.connectionTimeout ||
      type == DioExceptionType.sendTimeout ||
      type == DioExceptionType.receiveTimeout;
}
