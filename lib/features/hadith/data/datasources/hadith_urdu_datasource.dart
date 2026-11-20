import 'package:dio/dio.dart';

import '../../../../core/network/api_endpoints.dart';

/// Fetches the Urdu translation of one hadith.
///
/// These are static files on a CDN, not UmmahAPI, so this has its own client:
/// no auth, no shared base URL, and a short timeout, because the reader shows
/// English straight away when Urdu isn't there.
class HadithUrduDataSource {
  final Dio _dio;

  HadithUrduDataSource({Dio? dio}) : _dio = dio ?? createClient();

  /// The client used in production; tests put a fake adapter on it so they
  /// exercise the same status handling.
  static Dio createClient() => Dio(
    BaseOptions(
      connectTimeout: timeout,
      sendTimeout: timeout,
      receiveTimeout: timeout,
      // 403/404 mean "this hadith has no Urdu file", not a failure.
      validateStatus: (code) => code != null && code < 500,
    ),
  );

  static const timeout = Duration(seconds: 8);

  /// The Urdu text; `''` when the source confirms there is none; `null` when
  /// we couldn't find out (offline, timeout, server error) so the caller does
  /// not remember it as "none".
  Future<String?> fetch(String collection, int number) async {
    try {
      final response = await _dio.get<Object?>(
        ApiEndpoints.hadithUrdu(collection, number),
      );
      if (response.statusCode != 200) return '';
      final data = response.data;
      if (data is! Map) return '';
      final hadiths = data['hadiths'];
      if (hadiths is! List || hadiths.isEmpty) return '';
      final first = hadiths.first;
      final text = first is Map ? first['text'] : null;
      return text is String ? text.trim() : '';
    } catch (_) {
      return null;
    }
  }
}
