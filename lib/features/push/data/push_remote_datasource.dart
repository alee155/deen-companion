import 'package:dio/dio.dart';

import '../../../core/network/api_endpoints.dart';

/// The two push calls on the Deen Companion backend. Both need the signed-in
/// user's token (added by the app's Dio client).
abstract class PushRemoteDataSource {
  /// `PUT /notifications/device-token`. Idempotent: sending the same token
  /// again is harmless, and a token last held by another user moves to this
  /// one.
  Future<void> register({required String token, required String platform});

  /// `DELETE /notifications/device-token`. Succeeds for an unknown token too.
  Future<void> unregister(String token);
}

class PushRemoteDataSourceImpl implements PushRemoteDataSource {
  final Dio dio;
  const PushRemoteDataSourceImpl(this.dio);

  @override
  Future<void> register({required String token, required String platform}) =>
      dio.put<dynamic>(
        ApiEndpoints.deviceToken,
        data: {'token': token, 'platform': platform},
      );

  @override
  Future<void> unregister(String token) =>
      dio.delete<dynamic>(ApiEndpoints.deviceToken, data: {'token': token});
}
