import 'package:dio/dio.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/api_error_mapper.dart';
import '../../domain/entities/otp_purpose.dart';
import '../models/auth_user_model.dart';

/// Every response is `{success, data?}`; errors are
/// `{success:false, statusCode, message}` (see [mapDioException]).
/// The Bearer token is attached by the Dio `AuthInterceptor`, not here.
abstract class AuthRemoteDataSource {
  Future<AuthTokenResponseModel> register({
    required String name,
    required String email,
    required String password,
  });

  Future<AuthTokenResponseModel> login({
    required String email,
    required String password,
  });

  Future<VerifyEmailResponseModel> verifyEmail({
    required String email,
    required String otp,
  });

  Future<void> resendOtp({required String email, required OtpPurpose purpose});
  Future<void> forgotPassword({required String email});
  Future<void> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
  });

  /// `GET /auth/me` — `data` is the user object itself (not `{user}`).
  Future<AuthUserModel> getMe();
  Future<void> deleteAccount();
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final Dio dio;
  const AuthRemoteDataSourceImpl(this.dio);

  @override
  Future<AuthTokenResponseModel> register({
    required String name,
    required String email,
    required String password,
  }) => _data(
    () => dio.post(
      ApiEndpoints.authRegister,
      data: {'name': name, 'email': email, 'password': password},
    ),
    AuthTokenResponseModel.fromJson,
  );

  @override
  Future<AuthTokenResponseModel> login({
    required String email,
    required String password,
  }) => _data(
    () => dio.post(
      ApiEndpoints.authLogin,
      data: {'email': email, 'password': password},
    ),
    AuthTokenResponseModel.fromJson,
  );

  @override
  Future<VerifyEmailResponseModel> verifyEmail({
    required String email,
    required String otp,
  }) => _data(
    () => dio.post(
      ApiEndpoints.authVerifyEmail,
      data: {'email': email, 'otp': otp},
    ),
    VerifyEmailResponseModel.fromJson,
  );

  @override
  Future<void> resendOtp({
    required String email,
    required OtpPurpose purpose,
  }) => _ack(
    () => dio.post(
      ApiEndpoints.authResendOtp,
      data: {
        'email': email,
        'type': switch (purpose) {
          OtpPurpose.verifyEmail => 'verify_email',
          OtpPurpose.resetPassword => 'reset_password',
        },
      },
    ),
  );

  @override
  Future<void> forgotPassword({required String email}) => _ack(
    () => dio.post(ApiEndpoints.authForgotPassword, data: {'email': email}),
  );

  @override
  Future<void> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
  }) => _ack(
    () => dio.post(
      ApiEndpoints.authResetPassword,
      data: {'email': email, 'otp': otp, 'newPassword': newPassword},
    ),
  );

  @override
  Future<AuthUserModel> getMe() =>
      _data(() => dio.get(ApiEndpoints.authMe), AuthUserModel.fromJson);

  @override
  Future<void> deleteAccount() =>
      _ack(() => dio.delete(ApiEndpoints.authAccount));

  /// For endpoints whose success body carries a `data` object we need.
  Future<T> _data<T>(
    Future<Response<dynamic>> Function() call,
    T Function(Map<String, dynamic>) parse,
  ) async {
    try {
      final body = (await call()).data as Map<String, dynamic>;
      if (body['success'] != true) throw const ServerException();
      return parse(body['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw mapDioException(e);
    } on TypeError {
      // Response didn't match the observed shape.
      throw const ServerException();
    }
  }

  /// For endpoints where only success matters (resend-otp returns just
  /// `{success: true}`; the others a human message we don't need).
  Future<void> _ack(Future<Response<dynamic>> Function() call) async {
    try {
      final body = (await call()).data;
      if (body is Map && body['success'] == false) {
        throw const ServerException();
      }
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }
}
