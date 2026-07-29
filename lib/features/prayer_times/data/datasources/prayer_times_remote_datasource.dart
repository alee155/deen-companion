import 'package:dio/dio.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/location/location_service.dart';
import '../models/prayer_times_model.dart';

abstract class PrayerTimesRemoteDataSource {
  Future<PrayerTimesModel> getTimings(
    Coordinates coordinates, {
    required int method,
    required int school,
  });

  /// Every day's timings for a given Gregorian month, via AlAdhan's
  /// calendar endpoint — powers the monthly Prayer Calendar screen.
  Future<List<PrayerTimesModel>> getMonthCalendar(
    Coordinates coordinates, {
    required int year,
    required int month,
    required int method,
    required int school,
  });
}

class PrayerTimesRemoteDataSourceImpl implements PrayerTimesRemoteDataSource {
  final Dio dio;
  const PrayerTimesRemoteDataSourceImpl(this.dio);

  @override
  Future<PrayerTimesModel> getTimings(
    Coordinates coordinates, {
    required int method,
    required int school,
  }) async {
    try {
      final response = await dio.get(
        'https://api.aladhan.com/v1/timings/${DateTime.now().millisecondsSinceEpoch ~/ 1000}',
        queryParameters: {
          'latitude': coordinates.latitude,
          'longitude': coordinates.longitude,
          'method': method,
          'school': school,
        },
      );
      return PrayerTimesModel.fromApiJson(
        response.data as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      throw ServerException(e.message);
    }
  }

  @override
  Future<List<PrayerTimesModel>> getMonthCalendar(
    Coordinates coordinates, {
    required int year,
    required int month,
    required int method,
    required int school,
  }) async {
    try {
      final response = await dio.get(
        'https://api.aladhan.com/v1/calendar/$year/$month',
        queryParameters: {
          'latitude': coordinates.latitude,
          'longitude': coordinates.longitude,
          'method': method,
          'school': school,
        },
      );
      final days = response.data['data'] as List<dynamic>;
      // Each entry has the exact same {timings, date} shape as the
      // single-day /timings response's "data" object, so the existing
      // parser can be reused as-is for every day in the month.
      return days
          .map(
            (day) => PrayerTimesModel.fromApiJson({
              'data': day as Map<String, dynamic>,
            }),
          )
          .toList();
    } on DioException catch (e) {
      throw ServerException(e.message);
    }
  }
}
