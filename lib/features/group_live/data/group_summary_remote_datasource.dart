import '../../../core/utils/flow_log.dart';
import 'dart:io' show HttpDate;

import 'package:dio/dio.dart';

import '../../../core/error/exceptions.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/network/api_error_mapper.dart';
import '../domain/group_summary.dart';

sealed class SummaryResponse {
  /// The server's clock for this answer (the `Date` header, UTC, one-second
  /// resolution), or null when the header is missing.
  final DateTime? serverTime;
  const SummaryResponse(this.serverTime);
}

class SummaryFresh extends SummaryResponse {
  final GroupSummary summary;
  final String? etag;
  const SummaryFresh(this.summary, this.etag, super.serverTime);
}

/// `304`: what the caller already holds is current.
class SummaryNotModified extends SummaryResponse {
  const SummaryNotModified(super.serverTime);
}

/// `GET /groups/{id}/summary`. Members only: `403` means the caller is not (or
/// no longer) in the group, `404` that it does not exist; both surface as a
/// [ServerException] with that status.
abstract class GroupSummaryRemoteDataSource {
  Future<SummaryResponse> fetch(String groupId, {String? etag});
}

class GroupSummaryRemoteDataSourceImpl implements GroupSummaryRemoteDataSource {
  final Dio dio;
  const GroupSummaryRemoteDataSourceImpl(this.dio);

  @override
  Future<SummaryResponse> fetch(String groupId, {String? etag}) async {
    try {
      final response = await dio.get(
        ApiEndpoints.groupSummary(groupId),
        options: Options(
          headers: {'If-None-Match': ?etag},
          validateStatus: (s) =>
              s != null && ((s >= 200 && s < 300) || s == 304),
        ),
      );
      final serverTime = _parseDate(response.headers.value('date'));
      if (response.statusCode == 304) return SummaryNotModified(serverTime);
      final body = response.data as Map<String, dynamic>;
      if (body['success'] != true) throw const ServerException();
      return SummaryFresh(
        GroupSummary.fromJson(body['data'] as Map<String, dynamic>),
        response.headers.value('etag'),
        serverTime,
      );
    } on DioException catch (e) {
      FlowLog.log(
        'REALTIME',
        'SUMMARY REQUEST FAILED for group ${FlowLog.mask(groupId)}: '
            '${e.response?.statusCode ?? e.type.name}',
      );
      throw mapDioException(e);
    } on TypeError {
      throw const ServerException();
    }
  }

  static DateTime? _parseDate(String? raw) {
    if (raw == null) return null;
    try {
      return HttpDate.parse(raw).toUtc();
    } on Exception {
      return null;
    }
  }
}
