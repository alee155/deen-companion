import 'package:dio/dio.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/api_error_mapper.dart';

/// Public endpoint, 60 requests a minute per IP.
abstract class VideosRemoteDataSource {
  /// The `data` object: `{date, validUntil, count, videos}`.
  Future<Map<String, dynamic>> getRandom({int? count});
}

class VideosRemoteDataSourceImpl implements VideosRemoteDataSource {
  final Dio dio;
  const VideosRemoteDataSourceImpl(this.dio);

  @override
  Future<Map<String, dynamic>> getRandom({int? count}) async {
    try {
      final res = await dio.get(
        ApiEndpoints.videosRandom,
        queryParameters: {'count': ?count},
      );
      final body = res.data as Map<String, dynamic>;
      if (body['success'] != true) throw const ServerException();
      return body['data'] as Map<String, dynamic>;
    } on DioException catch (e) {
      throw mapDioException(e);
    } on TypeError {
      throw const ServerException();
    }
  }
}
