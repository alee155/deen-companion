import 'package:dio/dio.dart';
import '../error/exceptions.dart';

/// Turns a [DioException] from the Deen Companion backend into the app's
/// data-layer exceptions, surfacing the server's own message when it sent one
/// (e.g. "Invalid or expired OTP") so the UI can show something actionable.
///
/// Handles the common error body shapes: `{message: "..."}`,
/// `{message: ["...", "..."]}` (validation lists) and `{error: "..."}`.
Exception mapDioException(DioException e) {
  switch (e.type) {
    case DioExceptionType.connectionError:
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
      return const NetworkException();
    default:
      return ServerException(extractServerMessage(e.response?.data));
  }
}

String? extractServerMessage(Object? body) {
  if (body is! Map) return null;
  for (final key in const ['message', 'error']) {
    final v = body[key];
    if (v is String && v.trim().isNotEmpty) return v.trim();
    if (v is List && v.isNotEmpty) {
      return v.map((e) => e.toString()).join('\n');
    }
    if (v is Map) {
      final nested = extractServerMessage(v);
      if (nested != null) return nested;
    }
  }
  return null;
}
