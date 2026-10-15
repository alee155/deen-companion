import 'package:dio/dio.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/location/location_service.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/api_error_mapper.dart';
import '../models/server_prayer_times_models.dart';
import '../../domain/entities/prayer_times_bundle.dart';

/// The Deen backend's prayer-times API. Responses are `{success, data}`;
/// errors are mapped by [mapDioException].
///
/// Guest calls send `X-Device-Id` (the rate-limit key, so phones behind one
/// carrier address don't share a limit). Account calls get their Bearer token
/// from the Dio `AuthInterceptor`.
abstract class PrayerTimesRemoteDataSource {
  Future<PrayerTimesBundleModel> guestTimes(
    Coordinates coordinates, {
    int? method,
    int? school,
    required int days,
  });

  Future<PrayerTimesBundleModel> guestMonth(
    Coordinates coordinates, {
    required int year,
    required int month,
    int? method,
    int? school,
  });

  Future<SavedPrayerSettings> getSavedSettings();

  Future<PrayerTimesBundleModel> putLocation(
    Coordinates coordinates, {
    int? method,
    int? school,
  });

  Future<PrayerTimesBundleModel> accountTimes({required int days});

  Future<PrayerTimesBundleModel> accountMonth({
    required int year,
    required int month,
  });

  Future<void> clearLocation();

  Future<List<PrayerCity>> searchCities(String query, {int limit});

  Future<List<CalculationMethodOption>> getMethods();
}

class PrayerTimesRemoteDataSourceImpl implements PrayerTimesRemoteDataSource {
  final Dio dio;

  /// Reads the persisted device id (see `DeviceIdStore`).
  final Future<String> Function() deviceId;

  const PrayerTimesRemoteDataSourceImpl(this.dio, {required this.deviceId});

  /// The first request for a new area or month makes the server fetch from
  /// its provider, which can take a few seconds.
  static const _timeout = Duration(seconds: 30);

  Options get _slow => Options(receiveTimeout: _timeout, sendTimeout: _timeout);

  Future<Options> _guest() async => Options(
    receiveTimeout: _timeout,
    sendTimeout: _timeout,
    headers: {'X-Device-Id': await deviceId()},
  );

  static Map<String, dynamic> _place(
    Coordinates c, {
    int? method,
    int? school,
  }) => {
    'latitude': c.latitude,
    'longitude': c.longitude,
    'method': ?method,
    'school': ?school,
  };

  @override
  Future<PrayerTimesBundleModel> guestTimes(
    Coordinates coordinates, {
    int? method,
    int? school,
    required int days,
  }) => _call(
    () async => dio.get(
      ApiEndpoints.guestPrayerTimes,
      queryParameters: {
        ..._place(coordinates, method: method, school: school),
        'days': days,
      },
      options: await _guest(),
    ),
    _bundle,
  );

  @override
  Future<PrayerTimesBundleModel> guestMonth(
    Coordinates coordinates, {
    required int year,
    required int month,
    int? method,
    int? school,
  }) => _call(
    () async => dio.get(
      ApiEndpoints.guestPrayerTimesMonth,
      queryParameters: {
        ..._place(coordinates, method: method, school: school),
        'year': year,
        'month': month,
      },
      options: await _guest(),
    ),
    _bundle,
  );

  @override
  Future<SavedPrayerSettings> getSavedSettings() => _call(
    () async => dio.get(ApiEndpoints.prayerLocation),
    (data) => savedSettingsFromJson(data as Map<String, dynamic>),
  );

  @override
  Future<PrayerTimesBundleModel> putLocation(
    Coordinates coordinates, {
    int? method,
    int? school,
  }) => _call(
    () async => dio.put(
      ApiEndpoints.prayerLocation,
      data: _place(coordinates, method: method, school: school),
      options: _slow,
    ),
    _bundle,
  );

  @override
  Future<PrayerTimesBundleModel> accountTimes({required int days}) => _call(
    () async => dio.get(
      ApiEndpoints.accountPrayerTimes,
      queryParameters: {'days': days},
      options: _slow,
    ),
    _bundle,
  );

  @override
  Future<PrayerTimesBundleModel> accountMonth({
    required int year,
    required int month,
  }) => _call(
    () async => dio.get(
      ApiEndpoints.accountPrayerTimesMonth,
      queryParameters: {'year': year, 'month': month},
      options: _slow,
    ),
    _bundle,
  );

  @override
  Future<void> clearLocation() =>
      _call(() async => dio.delete(ApiEndpoints.prayerLocation), (_) {});

  @override
  Future<List<PrayerCity>> searchCities(String query, {int limit = 8}) => _call(
    () async => dio.get(
      ApiEndpoints.prayerCities,
      queryParameters: {'q': query, 'limit': limit},
      options: await _guest(),
    ),
    (data) => [
      for (final c in ((data as Map)['cities'] as List))
        prayerCityFromJson(c as Map<String, dynamic>),
    ],
  );

  @override
  Future<List<CalculationMethodOption>> getMethods() => _call(
    () async => dio.get(ApiEndpoints.prayerMethods, options: _slow),
    (data) {
      // The body may be the list itself or `{methods: [...]}`.
      final list = data is List ? data : (data as Map)['methods'] as List;
      return [
        for (final m in list) methodOptionFromJson(m as Map<String, dynamic>),
      ];
    },
  );

  static PrayerTimesBundleModel _bundle(dynamic data) =>
      PrayerTimesBundleModel.fromJson(data as Map<String, dynamic>);

  /// Runs [request], unwraps the envelope and parses its `data`. Parsing is
  /// inside the guard, so a response of the wrong shape is a
  /// [ServerException], not a stray cast error.
  Future<T> _call<T>(
    Future<Response<dynamic>> Function() request,
    T Function(dynamic data) parse,
  ) async {
    try {
      final body = (await request()).data as Map<String, dynamic>;
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
