import 'package:dio/dio.dart';
import '../../config/flavor_config.dart';

/// Attaches UmmahAPI's key to every outgoing request.
/// Header name below is a placeholder — confirm the exact header
/// UmmahAPI expects (commonly `x-api-key` or `Authorization: Bearer <key>`)
/// and adjust this one spot only.
class ApiKeyInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (options.uri.host.contains('ummahapi.com')) {
      options.headers['x-api-key'] = FlavorConfig.instance.ummahApiKey;
    }
    super.onRequest(options, handler);
  }
}
