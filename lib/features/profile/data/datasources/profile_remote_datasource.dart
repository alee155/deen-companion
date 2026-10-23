import 'package:dio/dio.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/api_error_mapper.dart';
import '../../domain/entities/user_profile.dart';
import '../models/profile_models.dart';

/// The Bearer token is attached by the Dio `AuthInterceptor`.
abstract class ProfileRemoteDataSource {
  Future<UserProfile> getProfile();
  Future<UserProfile> updateProfile({String? name, String? imagePath});
  Future<UserProfile> removeAvatar();
  Future<UserPoints> getPoints();
  Future<void> setTimezone(String timezone);
}

class ProfileRemoteDataSourceImpl implements ProfileRemoteDataSource {
  final Dio dio;
  const ProfileRemoteDataSourceImpl(this.dio);

  @override
  Future<UserProfile> getProfile() => _data(
    () => dio.get(ApiEndpoints.myProfile),
    (data) => userProfileFromJson(data as Map<String, dynamic>),
  );

  @override
  Future<UserProfile> updateProfile({String? name, String? imagePath}) =>
      _data(() async {
        // A name alone goes as JSON; a picture needs multipart.
        final Object body = imagePath == null
            ? {'name': name}
            : FormData.fromMap({
                'name': ?name,
                'file': await MultipartFile.fromFile(
                  imagePath,
                  filename: 'avatar${_extension(imagePath)}',
                  contentType: _mediaType(imagePath),
                ),
              });
        return dio.patch(ApiEndpoints.myProfile, data: body);
      }, (data) => userProfileFromJson(data as Map<String, dynamic>));

  @override
  Future<UserProfile> removeAvatar() => _data(
    () => dio.delete(ApiEndpoints.myAvatar),
    (data) => userProfileFromJson(data as Map<String, dynamic>),
  );

  @override
  Future<UserPoints> getPoints() => _data(
    () => dio.get(ApiEndpoints.myPoints),
    (data) => userPointsFromJson(data as Map<String, dynamic>),
  );

  @override
  Future<void> setTimezone(String timezone) => _data(
    () => dio.patch(ApiEndpoints.myTimezone, data: {'timezone': timezone}),
    (_) {},
  );

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
      // The body was not the expected shape.
      throw const ServerException();
    } on FormatException {
      throw const ServerException();
    }
  }
}
