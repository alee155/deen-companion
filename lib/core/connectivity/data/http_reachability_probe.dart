import 'package:dio/dio.dart';

import '../../network/api_endpoints.dart';
import '../domain/connectivity_ports.dart';

/// Reaches for our own backend with a HEAD request, so "online" means "the
/// thing this app needs is reachable", not "some website is".
///
/// Any HTTP answer counts, even a 404 or 500: the request got there and
/// back. Only a connection failure or a timeout means no. It deliberately
/// uses its own bare client, with no auth, retry or logging, so a probe can
/// never be mistaken for app traffic and never feeds back into itself.
class HttpReachabilityProbe implements ReachabilityProbe {
  final Dio _dio;

  HttpReachabilityProbe({
    Dio? dio,
    Duration timeout = const Duration(seconds: 4),
  }) : _dio =
           dio ??
           Dio(
             BaseOptions(
               connectTimeout: timeout,
               receiveTimeout: timeout,
               sendTimeout: timeout,
               validateStatus: (_) => true,
               followRedirects: false,
             ),
           );

  @override
  Future<bool> canReachBackend() async {
    try {
      await _dio.head('https://${ApiEndpoints.deenHost}/');
      return true;
    } on DioException {
      return false;
    } catch (_) {
      return false;
    }
  }
}
