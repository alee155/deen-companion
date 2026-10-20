import '../../../../core/usecase/usecase.dart';
import '../entities/user_profile.dart';

/// Nothing is cached: the avatar link is signed and expires, so each read
/// asks the server again.
abstract class ProfileRepository {
  /// `GET /users/me`.
  Future<Result<UserProfile>> getProfile();

  /// `PATCH /users/me`. At least one of [name] and [imagePath] is required;
  /// returns the profile as saved.
  Future<Result<UserProfile>> updateProfile({String? name, String? imagePath});

  /// `DELETE /users/me/avatar`. Returns the profile without a picture.
  Future<Result<UserProfile>> removeAvatar();

  /// `GET /users/me/points`.
  Future<Result<UserPoints>> getPoints();

  /// `PATCH /users/me/timezone` with an IANA name.
  Future<Result<void>> setTimezone(String timezone);
}
