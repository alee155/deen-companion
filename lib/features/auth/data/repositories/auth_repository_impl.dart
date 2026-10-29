import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/storage/token_storage.dart';
import '../../../../core/timezone/device_timezone.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../../core/utils/logger.dart';
import '../../domain/entities/auth_session.dart';
import '../../domain/entities/auth_user.dart';
import '../../domain/entities/gender.dart';
import '../../domain/entities/otp_purpose.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource remote;
  final TokenStorage tokenStorage;

  /// Sent on signup so a new account starts in the user's own timezone
  /// instead of the backend's `UTC` default.
  final DeviceTimezone? deviceTimezone;

  const AuthRepositoryImpl({
    required this.remote,
    required this.tokenStorage,
    this.deviceTimezone,
  });

  @override
  Future<Result<AuthUser>> login({
    required String email,
    required String password,
  }) => _guard('login', () async {
    final res = await remote.login(email: email, password: password);
    // An unverified account gets a token too, but it must not act as a
    // session until the OTP is verified — park it exactly like signup does.
    if (res.user.isEmailVerified) {
      await tokenStorage.saveAccessToken(res.accessToken);
    } else {
      await tokenStorage.savePendingToken(res.accessToken);
    }
    return res.user.toEntity();
  });

  @override
  Future<Result<AuthUser>> signup({
    required String name,
    required String email,
    required String password,
    required Gender gender,
  }) => _guard('signup', () async {
    final res = await remote.register(
      name: name,
      email: email,
      password: password,
      gender: gender,
      timezone: await deviceTimezone?.iana(),
    );
    // Parked, not active: the user isn't signed in until the OTP checks out.
    await tokenStorage.savePendingToken(res.accessToken);
    return res.user.toEntity();
  });

  @override
  Future<Result<AuthSession>> verifyOtp({
    required String email,
    required String code,
  }) => _guard('verifyOtp', () async {
    final res = await remote.verifyEmail(email: email, otp: code);
    final user = res.user.toEntity();
    if (!user.isEmailVerified) {
      throw const ServerException('Email could not be verified. Try again.');
    }
    if (!await tokenStorage.promotePendingToken()) {
      // Verified server-side, but this device holds no token, so there's
      // nothing to sign in with.
      throw const ServerException(
        'Your email is verified. Please log in to continue.',
      );
    }
    return user.toSession();
  });

  @override
  Future<Result<void>> resendOtp({
    required String email,
    OtpPurpose purpose = OtpPurpose.verifyEmail,
  }) => _guard(
    'resendOtp',
    () => remote.resendOtp(email: email, purpose: purpose),
  );

  @override
  Future<Result<void>> forgotPassword({required String email}) =>
      _guard('forgotPassword', () => remote.forgotPassword(email: email));

  @override
  Future<Result<void>> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
  }) => _guard(
    'resetPassword',
    () =>
        remote.resetPassword(email: email, otp: otp, newPassword: newPassword),
  );

  @override
  Future<Result<AuthUser>> getCurrentUser() =>
      _guard('getCurrentUser', () async => (await remote.getMe()).toEntity());

  @override
  Future<Result<void>> deleteAccount() => _guard('deleteAccount', () async {
    await remote.deleteAccount();
    await tokenStorage.clear();
  });

  Future<Result<T>> _guard<T>(String op, Future<T> Function() body) async {
    try {
      return Success(await body());
    } on NetworkException {
      return const Error(NetworkFailure());
    } on ServerException catch (e) {
      final m = e.message;
      return Error(m == null ? const ServerFailure() : ServerFailure(m));
    } catch (e, st) {
      AppLogger.e('AuthRepository: $op failed', e, st);
      return const Error(UnexpectedFailure());
    }
  }
}
