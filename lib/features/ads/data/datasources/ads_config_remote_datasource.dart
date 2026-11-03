import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/constants/app_constants.dart';
import '../../domain/entities/remote_ads_config.dart';

/// A successful answer from the ads service: a fresh [config], or
/// [notModified] when the `ETag` we sent still matches.
class AdsConfigFetch {
  final RemoteAdsConfig? config;
  final String? etag;
  final bool notModified;

  const AdsConfigFetch({this.config, this.etag, this.notModified = false});
}

/// The one public endpoint of the ads service. It has no login, so it uses its
/// own client rather than the app's authenticated one.
class AdsConfigRemoteDataSource {
  final Dio _dio;

  AdsConfigRemoteDataSource({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: AppConstants.adsConfigBaseUrl,
              connectTimeout: timeout,
              sendTimeout: timeout,
              receiveTimeout: timeout,
              validateStatus: (code) =>
                  code != null && ((code >= 200 && code < 300) || code == 304),
            ),
          );

  static const timeout = Duration(seconds: 5);

  /// Returns `null` on any failure (offline, timeout, 5xx, bad body); the
  /// caller then keeps whatever it had.
  Future<AdsConfigFetch?> fetch({
    required String appKey,
    required String platform,
    String? etag,
  }) async {
    try {
      final response = await _dio.get<Object?>(
        '/v1/apps/$appKey/ads',
        queryParameters: {'platform': platform},
        options: Options(headers: {'If-None-Match': ?etag}),
      );
      if (response.statusCode == 304) {
        return const AdsConfigFetch(notModified: true);
      }
      final data = response.data;
      if (data is! Map<String, dynamic>) return null;
      return AdsConfigFetch(
        config: RemoteAdsConfig.fromJson(data),
        etag: response.headers.value('etag'),
      );
    } catch (error) {
      debugPrint('[Ads] config fetch failed: $error');
      return null;
    }
  }
}
