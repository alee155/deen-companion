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
import '../../domain/entities/social_sign_in.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/services/social_auth_service.dart';
import '../datasources/auth_remote_datasource.dart';
import '../models/auth_user_model.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource remote;
  final TokenStorage tokenStorage;

  /// Sent on signup so a new account starts in the user's own timezone
  /// instead of the backend's `UTC` default.
  final DeviceTimezone? deviceTimezone;

  /// The Google and Apple sheets. Without it social sign-in is unavailable.
  final SocialAuthService? social;

  const AuthRepositoryImpl({
    required this.remote,
    required this.tokenStorage,
    this.deviceTimezone,
    this.social,
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
  Future<Result<SocialSignIn?>> signInWithGoogle() => _social(
    'Google',
    (service) => service.google(),
    (credential, timezone) =>
        remote.googleSignIn(idToken: credential.idToken, timezone: timezone),
  );

  @override
  Future<Result<SocialSignIn?>> signInWithApple() => _social(
    'Apple',
    (service) => service.apple(),
    (credential, timezone) => remote.appleSignIn(
      idToken: credential.idToken,
      authorizationCode: credential.authorizationCode ?? '',
      name: credential.name,
      timezone: timezone,
    ),
  );

  @override
  bool get appleSignInSupported => social?.appleSupported ?? false;

  /// The common path of both providers: show the provider's sheet, send what
  /// it returns, and keep the session. A social account is verified, so the
  /// token is active straight away (there is no OTP step).
  Future<Result<SocialSignIn?>> _social(
    String provider,
    Future<SocialCredential?> Function(SocialAuthService) ask,
    Future<AuthTokenResponseModel> Function(SocialCredential, String?) send,
  ) async {
    final service = social;
    if (service == null) {
      return Error(
        UnexpectedFailure('Sign in with $provider isn’t available.'),
      );
    }
    try {
      final credential = await ask(service);
      // The person closed the sheet.
      if (credential == null) return const Success(null);
      final res = await send(credential, await deviceTimezone?.iana());
      if (!res.user.isEmailVerified) {
        throw const ServerException(
          'We couldn’t confirm your email address. Please try again.',
        );
      }
      await tokenStorage.saveAccessToken(res.accessToken);
      return Success(
        SocialSignIn(user: res.user.toEntity(), isNewUser: res.isNewUser),
      );
    } on SocialAuthException catch (e) {
      return Error(UnexpectedFailure(e.message));
    } on NetworkException {
      return const Error(NetworkFailure());
    } on ServerException catch (e) {
      return Error(ServerFailure(_socialMessage(e, provider)));
    } catch (e, st) {
      AppLogger.e('AuthRepository: $provider sign-in failed', e, st);
      return const Error(UnexpectedFailure());
    }
  }

  /// What to tell the person for a failed social sign-in. The backend's own
  /// messages are for developers.
  static String _socialMessage(ServerException e, String provider) {
    final text = (e.message ?? '').toLowerCase();
    if (e.statusCode == 503 || text.contains('not configured')) {
      return 'Sign in with $provider isn’t available right now. Please try '
          'again later.';
    }
    if (e.statusCode == 409 || text.contains('already linked')) {
      return 'This email is already linked to a different $provider account. '
          'Please use the way you signed in before.';
    }
    if (text.contains('no verified email')) {
      return 'We need a verified email address from your $provider account to '
          'sign you in.';
    }
    if (text.contains('invalid') && text.contains('token')) {
      return 'We couldn’t verify your $provider sign-in. Please try again.';
    }
    if (e.statusCode == 401) {
      // `Invalid credentials` here means the account was deactivated.
      return 'This account can’t be used to sign in right now.';
    }
    return e.message ?? const ServerFailure().message;
  }

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
