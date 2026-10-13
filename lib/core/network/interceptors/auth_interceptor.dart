import 'package:dio/dio.dart';
import '../../storage/token_storage.dart';
import '../api_endpoints.dart';

/// Adds `Authorization: Bearer <accessToken>` to Deen Companion backend
/// requests whenever the user is signed in. Scoped by host so the token never
/// leaks to third-party APIs (UmmahAPI, Aladhan, ...). Only the verified
/// access token is used — never the pending, pre-verification one.
///
/// Also handles an expired/revoked token: a 401 on a request that carried one
/// clears the stored token and fires [onUnauthorized] so the session ends.
/// (The backend exposes no refresh endpoint, so re-login is the only fix.)
class AuthInterceptor extends Interceptor {
  final TokenStorage tokenStorage;
  final void Function()? onUnauthorized;
  const AuthInterceptor(this.tokenStorage, {this.onUnauthorized});

  /// These return 401 for bad credentials, which is not a dead session.
  static const _credentialPaths = ['/auth/login', '/auth/register'];

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (options.uri.host == ApiEndpoints.deenHost) {
      final token = await tokenStorage.readAccessToken();
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final req = err.requestOptions;
    if (err.response?.statusCode == 401 &&
        req.uri.host == ApiEndpoints.deenHost &&
        req.headers.containsKey('Authorization') &&
        !_credentialPaths.any(req.uri.path.endsWith)) {
      await tokenStorage.clear();
      onUnauthorized?.call();
    }
    handler.next(err);
  }
}
