import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../../domain/entities/auth_session.dart';
import '../../domain/repositories/auth_repository.dart';

/// TODO(auth-backend): every method here is a placeholder. Replace the body
/// with real calls once the API/flow is provided — the interface
/// ([AuthRepository]) and every call site above it are already in place, so
/// that swap shouldn't require any presentation-layer changes.
class AuthRepositoryImpl implements AuthRepository {
  const AuthRepositoryImpl();

  @override
  Future<Result<AuthSession>> login({
    required String email,
    required String password,
  }) async {
    return const Error(NotImplementedFailure());
  }

  @override
  Future<Result<AuthSession>> signup({
    required String name,
    required String email,
    required String password,
  }) async {
    return const Error(NotImplementedFailure());
  }

  @override
  Future<Result<void>> sendOtp({required String email}) async {
    return const Error(NotImplementedFailure());
  }

  @override
  Future<Result<AuthSession>> verifyOtp({
    required String email,
    required String code,
  }) async {
    return const Error(NotImplementedFailure());
  }

  @override
  Future<Result<void>> resendOtp({required String email}) async {
    return const Error(NotImplementedFailure());
  }
}
