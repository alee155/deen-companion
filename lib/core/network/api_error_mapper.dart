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
      return ServerException(
        extractServerMessage(e.response?.data),
        e.response?.statusCode,
        extractServerCode(e.response?.data),
        extractServerData(e.response?.data),
      );
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

/// The backend's machine-readable error code, if the body has one
/// (`{code: "PRAYER_DAY_LOCKED"}`, also seen as `errorCode`).
String? extractServerCode(Object? body) {
  if (body is! Map) return null;
  for (final key in const ['code', 'errorCode']) {
    final v = body[key];
    if (v is String && v.trim().isNotEmpty) return v.trim();
  }
  return null;
}

/// The error body's optional `data` object, if it is one.
Map<String, dynamic>? extractServerData(Object? body) {
  if (body is! Map) return null;
  final v = body['data'];
  return v is Map ? Map<String, dynamic>.from(v) : null;
}
