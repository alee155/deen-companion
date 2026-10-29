import 'package:dio/dio.dart';
import '../../../core/error/exceptions.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/network/api_error_mapper.dart';
import '../domain/current_prayer.dart';
import '../domain/group_member_prayers.dart';
import '../domain/prayer_log.dart';
import 'prayer_log_models.dart';

/// `/api/prayers/*`. The Bearer token is attached by the Dio `AuthInterceptor`.
abstract class PrayerLogsRemoteDataSource {
  /// `POST /prayers/logs` — multipart with a single `file` field (JPEG, PNG
  /// or WebP, ≤ 5 MB). Nothing else is sent: the server picks the prayer from
  /// its own clock, so the client can't claim a different one.
  Future<PrayerLog> logPrayer(
    String imagePath, {
    int? viewSeconds,
    List<String>? groupIds,
  });

  /// `DELETE /prayers/logs/{id}` — owner only, and only while the window is
  /// still open (400 afterwards). Also removes the photo.
  Future<void> deleteLog(String id);

  /// `POST /prayers/logs/{id}/groups` with `{groupIds}`.
  Future<PrayerLog> addSnapGroups(String logId, List<String> groupIds);

  /// `POST /prayers/logs/{id}/view` — no body. 410 once opened or expired.
  Future<OpenedSnap> viewSnap(String logId);

  /// `GET /groups/{id}/prayers?date=` — every member and their logs for one
  /// prayer-day (null [date] → the caller's today). Members only (403).
  Future<List<GroupMemberPrayers>> getGroupPrayers(
    String groupId, {
    String? date,
  });

  /// `GET /prayers/current` — the open prayer and the next one.
  Future<CurrentPrayerState> getCurrent();

  /// `GET /prayers/logs?date=` — the caller's own logs for one prayer-day.
  /// A null [date] means the user's today in their profile timezone, which
  /// only the server can compute reliably.
  Future<List<PrayerLog>> getLogs({String? date});

  /// `GET /prayers/logs/range` — up to 62 days, flat, ordered by date then
  /// prayer. Group with `groupLogsByDate`.
  Future<List<PrayerLog>> getLogsRange({
    required String from,
    required String to,
  });
}

class PrayerLogsRemoteDataSourceImpl implements PrayerLogsRemoteDataSource {
  final Dio dio;
  const PrayerLogsRemoteDataSourceImpl(this.dio);

  @override
  Future<PrayerLog> logPrayer(
    String imagePath, {
    int? viewSeconds,
    List<String>? groupIds,
  }) => _data(() async {
    final form = FormData.fromMap({
      'viewDurationSeconds': ?viewSeconds,
      'file': await MultipartFile.fromFile(
        imagePath,
        filename: 'snap${_extension(imagePath)}',
        contentType: _mediaType(imagePath),
      ),
    });
    // The field is repeated once per group (`groupIds=a&groupIds=b`).
    for (final id in groupIds ?? const <String>[]) {
      form.fields.add(MapEntry('groupIds', id));
    }
    return dio.post(ApiEndpoints.prayerLogs, data: form);
  }, (data) => prayerLogFromJson(data as Map<String, dynamic>));

  @override
  Future<PrayerLog> addSnapGroups(String logId, List<String> groupIds) => _data(
    () => dio.post(
      ApiEndpoints.prayerLogGroups(logId),
      data: {'groupIds': groupIds},
    ),
    (data) => prayerLogFromJson(data as Map<String, dynamic>),
  );

  @override
  Future<OpenedSnap> viewSnap(String logId) =>
      _data(() => dio.post(ApiEndpoints.prayerLogView(logId)), (data) {
        final json = data as Map<String, dynamic>;
        return OpenedSnap(
          url: json['snapUrl'] as String,
          viewDurationSeconds: (json['viewDurationSeconds'] as num?)?.toInt(),
        );
      });

  @override
  Future<void> deleteLog(String id) =>
      _data(() => dio.delete(ApiEndpoints.prayerLog(id)), (_) {});

  static String _extension(String path) {
    final dot = path.lastIndexOf('.');
    return dot < 0 ? '.jpg' : path.substring(dot).toLowerCase();
  }

  /// The server checks the real bytes, but also the declared type.
  static DioMediaType _mediaType(String path) => switch (_extension(path)) {
    '.png' => DioMediaType('image', 'png'),
    '.webp' => DioMediaType('image', 'webp'),
    _ => DioMediaType('image', 'jpeg'),
  };

  @override
  Future<List<GroupMemberPrayers>> getGroupPrayers(
    String groupId, {
    String? date,
  }) => _data(
    () => dio.get(
      ApiEndpoints.groupPrayers(groupId),
      queryParameters: date == null ? null : {'date': date},
    ),
    (data) => [
      for (final m in data as List)
        groupMemberPrayersFromJson(m as Map<String, dynamic>),
    ],
  );

  @override
  Future<CurrentPrayerState> getCurrent() => _data(
    () => dio.get(ApiEndpoints.prayerCurrent),
    (data) => currentPrayerStateFromJson(data as Map<String, dynamic>),
  );

  @override
  Future<List<PrayerLog>> getLogs({String? date}) => _data(
    () => dio.get(
      ApiEndpoints.prayerLogs,
      queryParameters: date == null ? null : {'date': date},
    ),
    _logList,
  );

  @override
  Future<List<PrayerLog>> getLogsRange({
    required String from,
    required String to,
  }) => _data(
    () => dio.get(
      ApiEndpoints.prayerLogsRange,
      queryParameters: {'from': from, 'to': to},
    ),
    _logList,
  );

  static List<PrayerLog> _logList(Object? data) => [
    for (final l in data as List) prayerLogFromJson(l as Map<String, dynamic>),
  ];

  /// Every success body is `{success: true, data}`.
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
    } on FormatException {
      throw const ServerException();
    }
  }
}
