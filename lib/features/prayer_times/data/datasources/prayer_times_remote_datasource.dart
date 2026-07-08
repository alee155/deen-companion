import 'package:dio/dio.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/location/location_service.dart';
import '../models/prayer_times_model.dart';

abstract class PrayerTimesRemoteDataSource {
  Future<PrayerTimesModel> getTimings(Coordinates coordinates);
}

class PrayerTimesRemoteDataSourceImpl implements PrayerTimesRemoteDataSource {
  final Dio dio;
  const PrayerTimesRemoteDataSourceImpl(this.dio);

  @override
  Future<PrayerTimesModel> getTimings(Coordinates coordinates) async {
    try {
      final response = await dio.get(
        'https://api.aladhan.com/v1/timings/${DateTime.now().millisecondsSinceEpoch ~/ 1000}',
        queryParameters: {
          'latitude': coordinates.latitude,
          'longitude': coordinates.longitude,
          'method': 2, // ISNA — swap per-region if needed later
        },
      );
      return PrayerTimesModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ServerException(e.message);
    }
  }
}
