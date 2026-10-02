import '../../../../core/usecase/usecase.dart';
import '../entities/auth_session.dart';

/// Contract for the auth backend. No implementation is wired up yet — see
/// [AuthRepositoryImpl] — this interface exists so the Login/Signup/OTP
/// screens can be built end-to-end now, and the real API/flow can be
/// dropped in behind it later without touching any presentation code.
abstract class AuthRepository {
  Future<Result<AuthSession>> login({
    required String email,
    required String password,
  });

  Future<Result<AuthSession>> signup({
    required String name,
    required String email,
    required String password,
  });

  /// Sends a verification code to [email]. Returns once the code has been
  /// dispatched, not once it's confirmed read.
  Future<Result<void>> sendOtp({required String email});

  Future<Result<AuthSession>> verifyOtp({
    required String email,
    required String code,
  });

  Future<Result<void>> resendOtp({required String email});
}
