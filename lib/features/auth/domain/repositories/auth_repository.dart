import '../../../../core/usecase/usecase.dart';
import '../entities/auth_session.dart';
import '../entities/auth_user.dart';
import '../entities/otp_purpose.dart';

abstract class AuthRepository {
  /// Authenticates with email + password. The backend also accepts accounts
  /// whose email is unverified; for those the returned user has
  /// `isEmailVerified == false`, the token is held aside (not active), and
  /// the caller must run OTP verification before the user counts as signed in.
  Future<Result<AuthUser>> login({
    required String email,
    required String password,
  });

  /// Creates the account and emails an OTP. The returned user is NOT signed
  /// in: their token is held aside until [verifyOtp] succeeds.
  Future<Result<AuthUser>> signup({
    required String name,
    required String email,
    required String password,
  });

  /// Verifies the emailed OTP. On success the held token becomes the active
  /// access token and the verified user is returned as a session.
  Future<Result<AuthSession>> verifyOtp({
    required String email,
    required String code,
  });

  /// Emails a fresh OTP for [purpose].
  Future<Result<void>> resendOtp({
    required String email,
    OtpPurpose purpose = OtpPurpose.verifyEmail,
  });

  /// Starts a password reset: emails a reset OTP. The backend answers the
  /// same way whether or not the account exists.
  Future<Result<void>> forgotPassword({required String email});

  Future<Result<void>> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
  });

  /// The signed-in user's current profile (requires the access token).
  Future<Result<AuthUser>> getCurrentUser();

  /// Permanently deletes the signed-in account and clears local tokens.
  Future<Result<void>> deleteAccount();
}
