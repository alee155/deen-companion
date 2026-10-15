import 'package:deen_companion/core/error/exceptions.dart';
import 'package:deen_companion/core/error/failures.dart';
import 'package:deen_companion/core/timezone/device_timezone.dart';
import 'package:deen_companion/core/usecase/usecase.dart';
import 'package:deen_companion/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:deen_companion/features/auth/data/models/auth_user_model.dart';
import 'package:deen_companion/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:deen_companion/features/auth/domain/entities/otp_purpose.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../_support/auth_fakes.dart';

class _MockRemote extends Mock implements AuthRemoteDataSource {}

class _FixedTimezone implements DeviceTimezone {
  final String? id;
  const _FixedTimezone(this.id);
  @override
  Future<String?> iana() async => id;
}

AuthUserModel _user({bool verified = false}) => AuthUserModel(
  id: 'u1',
  name: 'Alee',
  email: 'a@b.c',
  isEmailVerified: verified,
);

void main() {
  late _MockRemote remote;
  late MemoryTokens tokens;
  late AuthRepositoryImpl repo;

  setUpAll(() => registerFallbackValue(OtpPurpose.verifyEmail));

  setUp(() {
    remote = _MockRemote();
    tokens = MemoryTokens();
    repo = AuthRepositoryImpl(remote: remote, tokenStorage: tokens);
  });

  Failure failureOf<T>(Result<T> r) => (r as Error<T>).failure;

  When<Future<AuthTokenResponseModel>> stubRegister() => when(
    () => remote.register(
      name: any(named: 'name'),
      email: any(named: 'email'),
      password: any(named: 'password'),
      timezone: any(named: 'timezone'),
    ),
  );

  When<Future<AuthTokenResponseModel>> stubLogin() => when(
    () => remote.login(
      email: any(named: 'email'),
      password: any(named: 'password'),
    ),
  );

  When<Future<VerifyEmailResponseModel>> stubVerify() => when(
    () => remote.verifyEmail(
      email: any(named: 'email'),
      otp: any(named: 'otp'),
    ),
  );

  group('signup', () {
    test('sends the device timezone to register', () async {
      repo = AuthRepositoryImpl(
        remote: remote,
        tokenStorage: tokens,
        deviceTimezone: const _FixedTimezone('Asia/Karachi'),
      );
      stubRegister().thenAnswer(
        (_) async => AuthTokenResponseModel(accessToken: 'tok', user: _user()),
      );
      await repo.signup(name: 'Alee', email: 'a@b.c', password: 'pw');
      verify(
        () => remote.register(
          name: 'Alee',
          email: 'a@b.c',
          password: 'pw',
          timezone: 'Asia/Karachi',
        ),
      ).called(1);
    });

    test('parks the token as pending and does not activate it', () async {
      stubRegister().thenAnswer(
        (_) async => AuthTokenResponseModel(accessToken: 'tok', user: _user()),
      );
      final r = await repo.signup(name: 'Alee', email: 'a@b.c', password: 'pw');
      expect((r as Success).data.isEmailVerified, isFalse);
      expect(tokens.pending, 'tok');
      expect(tokens.access, isNull);
    });

    test('server message becomes ServerFailure', () async {
      stubRegister().thenThrow(const ServerException('Email already in use'));
      final r = await repo.signup(name: 'n', email: 'a@b.c', password: 'pw');
      expect(failureOf(r), isA<ServerFailure>());
      expect(failureOf(r).message, 'Email already in use');
      expect(tokens.pending, isNull);
    });

    test('network / unexpected errors are mapped', () async {
      stubRegister().thenThrow(const NetworkException());
      expect(
        failureOf(await repo.signup(name: 'n', email: 'a@b.c', password: 'pw')),
        isA<NetworkFailure>(),
      );
      stubRegister().thenThrow(StateError('x'));
      expect(
        failureOf(await repo.signup(name: 'n', email: 'a@b.c', password: 'pw')),
        isA<UnexpectedFailure>(),
      );
    });
  });

  group('login', () {
    test('verified account: token becomes the ACTIVE access token', () async {
      stubLogin().thenAnswer(
        (_) async => AuthTokenResponseModel(
          accessToken: 'tok',
          user: _user(verified: true),
        ),
      );
      final r = await repo.login(email: 'a@b.c', password: 'password1');
      expect((r as Success).data.isEmailVerified, isTrue);
      expect(tokens.access, 'tok');
      expect(tokens.pending, isNull);
    });

    test('unverified account: token is parked, not active', () async {
      stubLogin().thenAnswer(
        (_) async => AuthTokenResponseModel(accessToken: 'tok', user: _user()),
      );
      final r = await repo.login(email: 'a@b.c', password: 'password1');
      expect((r as Success).data.isEmailVerified, isFalse);
      expect(tokens.access, isNull);
      expect(tokens.pending, 'tok');
    });

    test('invalid credentials message is surfaced', () async {
      stubLogin().thenThrow(const ServerException('Invalid credentials'));
      final r = await repo.login(email: 'a@b.c', password: 'password1');
      expect(failureOf(r).message, 'Invalid credentials');
      expect(tokens.access, isNull);
    });
  });

  group('verifyOtp', () {
    test('promotes the pending token and returns a session', () async {
      tokens.pending = 'tok';
      stubVerify().thenAnswer(
        (_) async => VerifyEmailResponseModel(user: _user(verified: true)),
      );
      final r = await repo.verifyOtp(email: 'a@b.c', code: '1234');
      final session = (r as Success).data;
      expect(session.isAuthenticated, isTrue);
      expect(session.userId, 'u1');
      expect(tokens.access, 'tok');
      expect(tokens.pending, isNull);
    });

    test('wrong OTP surfaces the message and keeps pending', () async {
      tokens.pending = 'tok';
      stubVerify().thenThrow(const ServerException('Invalid or expired code'));
      final r = await repo.verifyOtp(email: 'a@b.c', code: '0000');
      expect(failureOf(r).message, 'Invalid or expired code');
      expect(tokens.access, isNull);
      expect(tokens.pending, 'tok');
    });

    test('unverified user in response is rejected', () async {
      tokens.pending = 'tok';
      stubVerify().thenAnswer(
        (_) async => VerifyEmailResponseModel(user: _user()),
      );
      expect(await repo.verifyOtp(email: 'a@b.c', code: '1234'), isA<Error>());
      expect(tokens.access, isNull);
    });

    test('no pending token → no session', () async {
      stubVerify().thenAnswer(
        (_) async => VerifyEmailResponseModel(user: _user(verified: true)),
      );
      expect(await repo.verifyOtp(email: 'a@b.c', code: '1234'), isA<Error>());
    });
  });

  group('resend / forgot / reset', () {
    test('resendOtp forwards the purpose', () async {
      when(
        () => remote.resendOtp(
          email: any(named: 'email'),
          purpose: any(named: 'purpose'),
        ),
      ).thenAnswer((_) async {});
      final r = await repo.resendOtp(
        email: 'a@b.c',
        purpose: OtpPurpose.resetPassword,
      );
      expect(r, isA<Success>());
      verify(
        () =>
            remote.resendOtp(email: 'a@b.c', purpose: OtpPurpose.resetPassword),
      ).called(1);
    });

    test('forgotPassword success and failure', () async {
      when(
        () => remote.forgotPassword(email: any(named: 'email')),
      ).thenAnswer((_) async {});
      expect(await repo.forgotPassword(email: 'a@b.c'), isA<Success>());
      when(
        () => remote.forgotPassword(email: any(named: 'email')),
      ).thenThrow(const NetworkException());
      expect(
        failureOf(await repo.forgotPassword(email: 'a@b.c')),
        isA<NetworkFailure>(),
      );
    });

    test('resetPassword failure carries the server message', () async {
      when(
        () => remote.resetPassword(
          email: any(named: 'email'),
          otp: any(named: 'otp'),
          newPassword: any(named: 'newPassword'),
        ),
      ).thenThrow(const ServerException('Invalid or expired code'));
      final r = await repo.resetPassword(
        email: 'a@b.c',
        otp: '0000',
        newPassword: 'newPassword456',
      );
      expect(failureOf(r).message, 'Invalid or expired code');
    });
  });

  group('getCurrentUser / deleteAccount', () {
    test('getCurrentUser maps the profile', () async {
      when(() => remote.getMe()).thenAnswer((_) async => _user(verified: true));
      final r = await repo.getCurrentUser();
      expect((r as Success).data.email, 'a@b.c');
    });

    test('getCurrentUser 401 is a failure', () async {
      when(
        () => remote.getMe(),
      ).thenThrow(const ServerException('Unauthorized'));
      expect(failureOf(await repo.getCurrentUser()).message, 'Unauthorized');
    });

    test('deleteAccount clears tokens only on success', () async {
      tokens.access = 'tok';
      when(() => remote.deleteAccount()).thenThrow(const NetworkException());
      expect(await repo.deleteAccount(), isA<Error>());
      expect(tokens.access, 'tok');

      when(() => remote.deleteAccount()).thenAnswer((_) async {});
      expect(await repo.deleteAccount(), isA<Success>());
      expect(tokens.access, isNull);
    });
  });
}
