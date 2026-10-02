// ignore_for_file: depend_on_referenced_packages
import 'package:fake_async/fake_async.dart';
import 'package:deen_companion/core/constants/app_constants.dart';
import 'package:deen_companion/core/error/failures.dart';
import 'package:deen_companion/core/storage/local_storage_service.dart';
import 'package:deen_companion/core/usecase/usecase.dart';
import 'package:deen_companion/features/auth/domain/entities/auth_session.dart';
import 'package:deen_companion/features/auth/domain/repositories/auth_repository.dart';
import 'package:deen_companion/features/auth/presentation/providers/auth_gate_provider.dart';
import 'package:deen_companion/features/auth/presentation/providers/auth_providers.dart';
import 'package:deen_companion/features/auth/presentation/providers/auth_session_provider.dart';
import 'package:deen_companion/features/auth/presentation/providers/forgot_password_controller.dart';
import 'package:deen_companion/features/auth/presentation/providers/login_controller.dart';
import 'package:deen_companion/features/auth/presentation/providers/otp_controller.dart';
import 'package:deen_companion/features/auth/presentation/providers/signup_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/in_memory_storage_service.dart';

class FakeAuthRepository implements AuthRepository {
  Result<AuthSession> loginResult = const Error(NotImplementedFailure());
  Result<AuthSession> signupResult = const Error(NotImplementedFailure());
  Result<void> sendOtpResult = const Success(null);
  Result<AuthSession> verifyResult = const Error(NotImplementedFailure());
  Result<void> resendResult = const Success(null);
  int resendCalls = 0;
  int sendOtpCalls = 0;
  String? lastEmail;

  @override
  Future<Result<AuthSession>> login({
    required String email,
    required String password,
  }) async {
    lastEmail = email;
    return loginResult;
  }

  @override
  Future<Result<AuthSession>> signup({
    required String name,
    required String email,
    required String password,
  }) async {
    lastEmail = email;
    return signupResult;
  }

  @override
  Future<Result<void>> sendOtp({required String email}) async {
    sendOtpCalls++;
    return sendOtpResult;
  }

  @override
  Future<Result<AuthSession>> verifyOtp({
    required String email,
    required String code,
  }) async => verifyResult;

  @override
  Future<Result<void>> resendOtp({required String email}) async {
    resendCalls++;
    return resendResult;
  }
}

ProviderContainer makeContainer(
  InMemoryStorageService storage,
  FakeAuthRepository repo,
) {
  final c = ProviderContainer(
    overrides: [
      localStorageServiceProvider.overrideWithValue(storage),
      authRepositoryProvider.overrideWithValue(repo),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

const _box = AppConstants.settingsBoxName;

void main() {
  late InMemoryStorageService storage;
  late FakeAuthRepository repo;
  late ProviderContainer container;

  setUp(() {
    storage = InMemoryStorageService();
    repo = FakeAuthRepository();
    container = makeContainer(storage, repo);
  });

  group('authRepositoryProvider default', () {
    test('resolves to a repository that is not implemented yet', () async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final r = await c
          .read(authRepositoryProvider)
          .login(email: 'a@b.c', password: 'p');
      expect((r as Error).failure, isA<NotImplementedFailure>());
    });
  });

  group('AuthSessionNotifier', () {
    test('starts as guest with empty storage', () {
      final s = container.read(authSessionProvider);
      expect(s.isGuest, isTrue);
    });

    test('restores persisted session', () {
      storage.boxes[_box] = {
        AppConstants.authUserIdKey: 'u1',
        AppConstants.authEmailKey: 'a@b.c',
        AppConstants.authNameKey: 'Ali',
      };
      final c = makeContainer(storage, repo);
      final s = c.read(authSessionProvider);
      expect(s.isAuthenticated, isTrue);
      expect(s.userId, 'u1');
      expect(s.email, 'a@b.c');
      expect(s.name, 'Ali');
      expect(s.photoUrl, isNull);
    });

    test('signIn persists fields and removes null ones', () async {
      storage.boxes[_box] = {AppConstants.authPhotoUrlKey: 'old.png'};
      final n = container.read(authSessionProvider.notifier);
      await n.signIn(const AuthSession(userId: 'u2', email: 'x@y.z'));
      expect(container.read(authSessionProvider).userId, 'u2');
      expect(storage.get<String>(_box, AppConstants.authUserIdKey), 'u2');
      expect(storage.get<String>(_box, AppConstants.authEmailKey), 'x@y.z');
      expect(storage.get<String>(_box, AppConstants.authNameKey), isNull);
      expect(storage.get<String>(_box, AppConstants.authPhotoUrlKey), isNull);
    });

    test('signIn ignores guest / id-less sessions', () async {
      final n = container.read(authSessionProvider.notifier);
      await n.signIn(const AuthSession.guest());
      await n.signIn(const AuthSession(email: 'a@b.c'));
      expect(container.read(authSessionProvider).isGuest, isTrue);
      expect(storage.getAll(_box), isEmpty);
    });

    test('signOut clears state and storage', () async {
      final n = container.read(authSessionProvider.notifier);
      await n.signIn(
        const AuthSession(
          userId: 'u',
          email: 'e@e.e',
          name: 'N',
          photoUrl: 'p',
        ),
      );
      await n.signOut();
      expect(container.read(authSessionProvider).isGuest, isTrue);
      expect(storage.getAll(_box), isEmpty);
    });
  });

  group('AuthGate', () {
    test('markSeen stores the flag', () async {
      await container.read(authGateProvider).markSeen();
      expect(storage.get<bool>(_box, AppConstants.authGateSeenKey), isTrue);
    });
  });

  group('LoginController', () {
    test('failure surfaces message and does not sign in', () async {
      await container
          .read(loginControllerProvider.notifier)
          .submit(email: 'a@b.c', password: 'p');
      final s = container.read(loginControllerProvider);
      expect(s.isSubmitting, isFalse);
      expect(s.errorMessage, const NotImplementedFailure().message);
      expect(container.read(authSessionProvider).isGuest, isTrue);
      expect(storage.get<bool>(_box, AppConstants.authGateSeenKey), isNull);
    });

    test('success signs in, marks gate seen, clears error', () async {
      repo.loginResult = const Success(
        AuthSession(userId: 'u9', email: 'a@b.c'),
      );
      await container
          .read(loginControllerProvider.notifier)
          .submit(email: 'a@b.c', password: 'p');
      expect(container.read(loginControllerProvider).errorMessage, isNull);
      expect(container.read(authSessionProvider).userId, 'u9');
      expect(storage.get<bool>(_box, AppConstants.authGateSeenKey), isTrue);
    });

    test('success with guest session leaves user signed out', () async {
      repo.loginResult = const Success(AuthSession.guest());
      await container
          .read(loginControllerProvider.notifier)
          .submit(email: 'a@b.c', password: 'p');
      expect(container.read(authSessionProvider).isGuest, isTrue);
    });
  });

  group('SignupController', () {
    test('failure surfaces message', () async {
      repo.signupResult = const Error(ServerFailure('boom'));
      await container
          .read(signupControllerProvider.notifier)
          .submit(name: 'n', email: 'a@b.c', password: 'p');
      expect(container.read(signupControllerProvider).errorMessage, 'boom');
      expect(container.read(authSessionProvider).isGuest, isTrue);
    });

    test('success signs in and marks gate', () async {
      repo.signupResult = const Success(AuthSession(userId: 'n1', name: 'N'));
      await container
          .read(signupControllerProvider.notifier)
          .submit(name: 'N', email: 'a@b.c', password: 'p');
      expect(container.read(signupControllerProvider).errorMessage, isNull);
      expect(container.read(authSessionProvider).name, 'N');
      expect(storage.get<bool>(_box, AppConstants.authGateSeenKey), isTrue);
    });
  });

  group('ForgotPasswordController', () {
    test('success returns true without error', () async {
      final ok = await container
          .read(forgotPasswordControllerProvider.notifier)
          .sendResetCode(email: 'a@b.c');
      expect(ok, isTrue);
      final s = container.read(forgotPasswordControllerProvider);
      expect(s.isSubmitting, isFalse);
      expect(s.errorMessage, isNull);
      expect(repo.sendOtpCalls, 1);
    });

    test('failure returns false with message, retry clears it', () async {
      repo.sendOtpResult = const Error(NetworkFailure());
      final n = container.read(forgotPasswordControllerProvider.notifier);
      expect(await n.sendResetCode(email: 'a@b.c'), isFalse);
      expect(
        container.read(forgotPasswordControllerProvider).errorMessage,
        const NetworkFailure().message,
      );
      repo.sendOtpResult = const Success(null);
      expect(await n.sendResetCode(email: 'a@b.c'), isTrue);
      expect(
        container.read(forgotPasswordControllerProvider).errorMessage,
        isNull,
      );
    });
  });

  group('OtpState', () {
    test('canResend requires no cooldown and not resending', () {
      expect(const OtpState().canResend, isTrue);
      expect(const OtpState(resendCooldownSeconds: 3).canResend, isFalse);
      expect(const OtpState(isResending: true).canResend, isFalse);
    });

    test('copyWith keeps error unless clearError', () {
      const s = OtpState(errorMessage: 'bad');
      expect(s.copyWith(isSubmitting: true).errorMessage, 'bad');
      expect(s.copyWith(clearError: true).errorMessage, isNull);
    });
  });

  group('OtpController', () {
    test('starts with a 30s cooldown that ticks down to zero', () {
      fakeAsync((async) {
        final sub = container.listen(otpControllerProvider, (_, _) {});
        expect(container.read(otpControllerProvider).resendCooldownSeconds, 30);
        expect(container.read(otpControllerProvider).canResend, isFalse);
        async.elapse(const Duration(seconds: 10));
        expect(container.read(otpControllerProvider).resendCooldownSeconds, 20);
        async.elapse(const Duration(seconds: 20));
        expect(container.read(otpControllerProvider).resendCooldownSeconds, 0);
        expect(container.read(otpControllerProvider).canResend, isTrue);
        sub.close();
      });
    });

    test('resend after cooldown calls repo and restarts cooldown', () {
      fakeAsync((async) {
        final sub = container.listen(otpControllerProvider, (_, _) {});
        async.elapse(const Duration(seconds: 31));
        container.read(otpControllerProvider.notifier).resend(email: 'a@b.c');
        async.flushMicrotasks();
        expect(repo.resendCalls, 1);
        expect(container.read(otpControllerProvider).resendCooldownSeconds, 30);
        expect(container.read(otpControllerProvider).isResending, isFalse);
        sub.close();
      });
    });

    test('resend failure keeps cooldown at zero and sets error', () {
      fakeAsync((async) {
        repo.resendResult = const Error(NetworkFailure());
        final sub = container.listen(otpControllerProvider, (_, _) {});
        async.elapse(const Duration(seconds: 31));
        container.read(otpControllerProvider.notifier).resend(email: 'a@b.c');
        async.flushMicrotasks();
        final s = container.read(otpControllerProvider);
        expect(s.errorMessage, const NetworkFailure().message);
        expect(s.canResend, isTrue);
        sub.close();
      });
    });

    test('resend is a no-op during cooldown', () async {
      final sub = container.listen(otpControllerProvider, (_, _) {});
      addTearDown(sub.close);
      await container
          .read(otpControllerProvider.notifier)
          .resend(email: 'a@b.c');
      expect(repo.resendCalls, 0);
    });

    test('verify success signs in', () async {
      final sub = container.listen(otpControllerProvider, (_, _) {});
      addTearDown(sub.close);
      repo.verifyResult = const Success(AuthSession(userId: 'v1'));
      await container
          .read(otpControllerProvider.notifier)
          .verify(email: 'a@b.c', code: '1234');
      expect(container.read(otpControllerProvider).isSubmitting, isFalse);
      expect(container.read(authSessionProvider).userId, 'v1');
      expect(storage.get<bool>(_box, AppConstants.authGateSeenKey), isTrue);
    });

    test('verify failure sets error, clearError removes it', () async {
      final sub = container.listen(otpControllerProvider, (_, _) {});
      addTearDown(sub.close);
      final n = container.read(otpControllerProvider.notifier);
      await n.verify(email: 'a@b.c', code: '0000');
      expect(
        container.read(otpControllerProvider).errorMessage,
        const NotImplementedFailure().message,
      );
      n.clearError();
      expect(container.read(otpControllerProvider).errorMessage, isNull);
    });
  });
}
