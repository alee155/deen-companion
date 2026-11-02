import 'package:dio/dio.dart';

import '../../../core/error/exceptions.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/network/api_error_mapper.dart';
import '../domain/entities/blocked_user.dart';

/// `/api/reports` and `/api/blocks`. The Bearer token is attached by the Dio
/// `AuthInterceptor`; every success body is `{success: true, data}`.
abstract class ModerationRemoteDataSource {
  /// `POST /reports` (10 a minute). [targetType] is `user` or `snap`; for a
  /// snap [targetId] is the log id and [groupId] the feed it was opened in.
  /// Reporting the same thing twice is a success, not an error.
  Future<void> report({
    required String targetType,
    required String targetId,
    required String reason,
    String? groupId,
    String? details,
  });

  /// `GET /blocks` — only the people you blocked, newest first.
  Future<List<BlockedUser>> getBlocked();

  /// `POST /blocks` `{userId}`. Blocking again is a success.
  Future<BlockedUser> block(String userId);

  /// `DELETE /blocks/{userId}`. Unblocking someone you never blocked is a
  /// success too.
  Future<void> unblock(String userId);
}

class ModerationRemoteDataSourceImpl implements ModerationRemoteDataSource {
  final Dio dio;
  const ModerationRemoteDataSourceImpl(this.dio);

  @override
  Future<void> report({
    required String targetType,
    required String targetId,
    required String reason,
    String? groupId,
    String? details,
  }) => _data(
    () => dio.post(
      ApiEndpoints.reports,
      data: {
        'targetType': targetType,
        'targetId': targetId,
        'reason': reason,
        'groupId': ?groupId,
        'details': ?details,
      },
    ),
    (_) {},
  );

  @override
  Future<List<BlockedUser>> getBlocked() =>
      _data(() => dio.get(ApiEndpoints.blocks), (data) {
        return [
          for (final item in data as List)
            if (BlockedUser.fromJson(item) case final b?) b,
        ];
      });

  @override
  Future<BlockedUser> block(String userId) => _data(
    () => dio.post(ApiEndpoints.blocks, data: {'userId': userId}),
    (data) => BlockedUser.fromJson(data) ?? (throw const ServerException()),
  );

  @override
  Future<void> unblock(String userId) =>
      _data(() => dio.delete(ApiEndpoints.block(userId)), (_) {});

  Future<T> _data<T>(
    Future<Response<dynamic>> Function() call,
    T Function(Object? data) parse,
  ) async {
    try {
      final body = (await call()).data as Map<String, dynamic>;
      if (body['success'] != true) throw const ServerException();
      return parse(body['data']);
    } on DioException catch (e) {
      throw mapDioException(e);
    } on TypeError {
      throw const ServerException();
    }
  }
}
