import 'package:dio/dio.dart';

import '../../../core/error/exceptions.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/network/api_error_mapper.dart';
import '../../prayer_times/domain/entities/prayer_times.dart';
import '../domain/special_days.dart';
import 'special_days_models.dart';

/// The Bearer token is attached by the Dio `AuthInterceptor`. Every call
/// answers with the state as it stands afterwards.
abstract class SpecialDaysRemoteDataSource {
  Future<SpecialDays> getState();
  Future<Map<PrayerName, SpecialDayImage>> getImages();
  Future<SpecialDays> setActive(bool active);
  Future<SpecialDays> uploadImage(PrayerName prayer, String path);
  Future<SpecialDays> removeImage(PrayerName prayer);
}

class SpecialDaysRemoteDataSourceImpl implements SpecialDaysRemoteDataSource {
  final Dio dio;
  const SpecialDaysRemoteDataSourceImpl(this.dio);

  @override
  Future<SpecialDays> getState() =>
      _data(() => dio.get(ApiEndpoints.exemption));

  @override
  Future<Map<PrayerName, SpecialDayImage>> getImages() async {
    try {
      final res = await dio.get(ApiEndpoints.exemptionImages);
      final body = res.data as Map<String, dynamic>;
      if (body['success'] != true) throw const ServerException();
      return specialDayImagesFromJson(body['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw mapDioException(e);
    } on TypeError {
      throw const ServerException();
    }
  }

  @override
  Future<SpecialDays> setActive(bool active) => _data(
    () => dio.put(ApiEndpoints.exemptionStatus, data: {'active': active}),
  );

  @override
  Future<SpecialDays> uploadImage(PrayerName prayer, String path) =>
      _data(() async {
        final form = FormData.fromMap({
          'file': await MultipartFile.fromFile(
            path,
            filename: '${prayer.name}${_extension(path)}',
            contentType: _mediaType(path),
          ),
        });
        return dio.put(ApiEndpoints.exemptionImage(prayer.name), data: form);
      });

  @override
  Future<SpecialDays> removeImage(PrayerName prayer) =>
      _data(() => dio.delete(ApiEndpoints.exemptionImage(prayer.name)));

  static String _extension(String path) {
    final dot = path.lastIndexOf('.');
    return dot < 0 ? '.jpg' : path.substring(dot).toLowerCase();
  }

  /// The server accepts JPEG, PNG and WebP only.
  static DioMediaType _mediaType(String path) => switch (_extension(path)) {
    '.png' => DioMediaType('image', 'png'),
    '.webp' => DioMediaType('image', 'webp'),
    _ => DioMediaType('image', 'jpeg'),
  };

  Future<SpecialDays> _data(Future<Response<dynamic>> Function() call) async {
    try {
      final body = (await call()).data as Map<String, dynamic>;
      if (body['success'] != true) throw const ServerException();
      return specialDaysFromJson(body['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw mapDioException(e);
    } on TypeError {
      throw const ServerException();
    } on FormatException {
      throw const ServerException();
    }
  }
}
