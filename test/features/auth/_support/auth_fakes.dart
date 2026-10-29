import 'package:deen_companion/features/auth/domain/entities/gender.dart';
import 'package:deen_companion/core/error/failures.dart';
import 'package:deen_companion/core/storage/token_storage.dart';
import 'package:deen_companion/core/usecase/usecase.dart';
import 'package:deen_companion/features/auth/domain/entities/auth_session.dart';
import 'package:deen_companion/features/auth/domain/entities/auth_user.dart';
import 'package:deen_companion/features/auth/domain/entities/otp_purpose.dart';
import 'package:deen_companion/features/auth/domain/repositories/auth_repository.dart';

/// In-memory [TokenStorage] mirroring the secure-storage slot semantics.
class MemoryTokens implements TokenStorage {
  String? access;
  String? pending;
  MemoryTokens({this.access, this.pending});

  @override
  Future<String?> readAccessToken() async => access;
  @override
  Future<String?> readPendingToken() async => pending;
  @override
  Future<void> savePendingToken(String token) async => pending = token;
  @override
  Future<void> saveAccessToken(String token) async {
    access = token;
    pending = null;
  }

  @override
  Future<bool> promotePendingToken() async {
    if (pending == null) return false;
    access = pending;
    pending = null;
    return true;
  }

  @override
  Future<void> clear() async => access = pending = null;
}

const verifiedUser = AuthUser(
  id: 'u1',
  name: 'Ali',
  email: 'a@b.c',
  isEmailVerified: true,
);
const unverifiedUser = AuthUser(
  id: 'u1',
  name: 'Ali',
  email: 'a@b.c',
  isEmailVerified: false,
);

class FakeAuthRepository implements AuthRepository {
  Result<AuthUser> loginResult = const Error(
    ServerFailure('Invalid credentials'),
  );
  Result<AuthUser> signupResult = const Error(NotImplementedFailure());
  Result<AuthSession> verifyResult = const Error(NotImplementedFailure());
  Result<void> resendResult = const Success(null);
  Result<void> forgotResult = const Success(null);
  Result<void> resetResult = const Success(null);
  Result<AuthUser> meResult = const Error(NetworkFailure());
  Result<void> deleteResult = const Success(null);

  int resendCalls = 0;
  int meCalls = 0;
  OtpPurpose? lastPurpose;
  String? lastEmail;
  Gender? lastGender;
  ({String email, String otp, String newPassword})? lastReset;

  @override
  Future<Result<AuthUser>> login({
    required String email,
    required String password,
  }) async {
    lastEmail = email;
    return loginResult;
  }

  @override
  Future<Result<AuthUser>> signup({
    required String name,
    required String email,
    required String password,
    required Gender gender,
  }) async {
    lastEmail = email;
    lastGender = gender;
    return signupResult;
  }

  @override
  Future<Result<AuthSession>> verifyOtp({
    required String email,
    required String code,
  }) async => verifyResult;

  @override
  Future<Result<void>> resendOtp({
    required String email,
    OtpPurpose purpose = OtpPurpose.verifyEmail,
  }) async {
    resendCalls++;
    lastPurpose = purpose;
    return resendResult;
  }

  @override
  Future<Result<void>> forgotPassword({required String email}) async {
    lastEmail = email;
    return forgotResult;
  }

  @override
  Future<Result<void>> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    lastReset = (email: email, otp: otp, newPassword: newPassword);
    return resetResult;
  }

  @override
  Future<Result<AuthUser>> getCurrentUser() async {
    meCalls++;
    return meResult;
  }

  @override
  Future<Result<void>> deleteAccount() async => deleteResult;
}
