import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../auth/domain/entities/gender.dart';
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

  /// `PATCH /users/me/gender`, for an account that has none yet. It can be set
  /// once and never changed: a second call fails with [GenderAlreadySet].
  Future<Result<void>> setGender(Gender gender);

  /// `PATCH /users/me/timezone` with an IANA name.
  Future<Result<void>> setTimezone(String timezone);
}

/// The account already has a gender (set elsewhere, or by an earlier call).
/// The value cannot change, so the caller just reads the profile again.
class GenderAlreadySet extends ServerFailure {
  const GenderAlreadySet()
    : super('Your gender is already set and can’t be changed.');
}
