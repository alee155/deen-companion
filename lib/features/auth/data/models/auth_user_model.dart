import '../../domain/entities/auth_user.dart';

class AuthUserModel {
  final String id;
  final String name;
  final String email;
  final bool isEmailVerified;
  final String? timezone;

  const AuthUserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.isEmailVerified,
    this.timezone,
  });

  factory AuthUserModel.fromJson(Map<String, dynamic> json) => AuthUserModel(
    id: json['id'] as String,
    name: json['name'] as String? ?? '',
    email: json['email'] as String,
    isEmailVerified: json['isEmailVerified'] as bool? ?? false,
    timezone: json['timezone'] as String?,
  );

  AuthUser toEntity() => AuthUser(
    id: id,
    name: name,
    email: email,
    isEmailVerified: isEmailVerified,
    timezone: timezone,
  );
}

/// `data` of `POST /auth/register` and `POST /auth/login`.
class AuthTokenResponseModel {
  final String accessToken;
  final AuthUserModel user;

  const AuthTokenResponseModel({required this.accessToken, required this.user});

  factory AuthTokenResponseModel.fromJson(Map<String, dynamic> json) =>
      AuthTokenResponseModel(
        accessToken: json['accessToken'] as String,
        user: AuthUserModel.fromJson(json['user'] as Map<String, dynamic>),
      );
}

/// `data` of `POST /auth/verify-email`.
class VerifyEmailResponseModel {
  final AuthUserModel user;

  const VerifyEmailResponseModel({required this.user});

  factory VerifyEmailResponseModel.fromJson(Map<String, dynamic> json) =>
      VerifyEmailResponseModel(
        user: AuthUserModel.fromJson(json['user'] as Map<String, dynamic>),
      );
}
