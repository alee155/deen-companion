// ignore_for_file: depend_on_referenced_packages
import 'package:deen_companion/core/constants/app_constants.dart';
import 'package:deen_companion/core/error/failures.dart';
import 'package:deen_companion/core/network/session_events.dart';
import 'package:deen_companion/core/storage/local_storage_service.dart';
import 'package:deen_companion/core/storage/token_storage.dart';
import 'package:deen_companion/core/usecase/usecase.dart';
import 'package:deen_companion/features/auth/domain/entities/auth_session.dart';
import 'package:deen_companion/features/auth/domain/entities/otp_purpose.dart';
import 'package:deen_companion/features/auth/presentation/providers/auth_gate_provider.dart';
import 'package:deen_companion/features/auth/presentation/providers/auth_providers.dart';
import 'package:deen_companion/features/auth/presentation/providers/auth_session_provider.dart';
import 'package:deen_companion/features/auth/presentation/providers/delete_account_controller.dart';
import 'package:deen_companion/features/auth/presentation/providers/forgot_password_controller.dart';
import 'package:deen_companion/features/auth/presentation/providers/login_controller.dart';
import 'package:deen_companion/features/auth/presentation/providers/otp_controller.dart';
import 'package:deen_companion/features/auth/presentation/providers/reset_password_controller.dart';
import 'package:deen_companion/features/auth/presentation/providers/signup_controller.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/in_memory_storage_service.dart';
import '../_support/auth_fakes.dart';

const _box = AppConstants.settingsBoxName;

void main() {
  late InMemoryStorageService storage;
  late FakeAuthRepository repo;
  late MemoryTokens tokens;
  late ProviderContainer container;

  ProviderContainer make() {
    final c = ProviderContainer(
      overrides: [
        localStorageServiceProvider.overrideWithValue(storage),
        authRepositoryProvider.overrideWithValue(repo),
        tokenStorageProvider.overrideWithValue(tokens),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  setUp(() {
    storage = InMemoryStorageService();
    repo = FakeAuthRepository();
    tokens = MemoryTokens(access: 'tok');
    container = make();
  });

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  group('AuthSessionNotifier', () {
    test('starts as guest with empty storage', () {
      expect(container.read(authSessionProvider).isGuest, isTrue);
      expect(repo.meCalls, 0);
    });

    test('restores persisted session and refreshes it from /me', () async {
      storage.boxes[_box] = {
        AppConstants.authUserIdKey: 'u1',
        AppConstants.authEmailKey: 'old@b.c',
        AppConstants.authNameKey: 'Old',
        AppConstants.authPhotoUrlKey: 'p.png',
      };
      repo.meResult = const Success(verifiedUser);
      final c = make();
      expect(c.read(authSessionProvider).name, 'Old');
      await settle();
      await settle();
      final s = c.read(authSessionProvider);
      expect(repo.meCalls, 1);
      expect(s.name, 'Ali');
      expect(s.email, 'a@b.c');
      expect(s.photoUrl, 'p.png'); // preserved
    });

    test('restored session with no access token is signed out', () async {
      storage.boxes[_box] = {AppConstants.authUserIdKey: 'u1'};
      tokens.access = null;
      final c = make();
      c.read(authSessionProvider); // build() kicks off the launch check
      await settle();
      await settle();
      expect(c.read(authSessionProvider).isGuest, isTrue);
      expect(storage.getAll(_box), isEmpty);
    });

    test('offline refresh keeps the session', () async {
      storage.boxes[_box] = {AppConstants.authUserIdKey: 'u1'};
      repo.meResult = const Error(NetworkFailure());
      final c = make();
      c.read(authSessionProvider);
      await settle();
      await settle();
      expect(c.read(authSessionProvider).isAuthenticated, isTrue);
    });

    test('unauthorized event (expired token) ends the session', () async {
      final n = container.read(authSessionProvider.notifier);
      await n.signIn(const AuthSession(userId: 'u', email: 'e@e.e'));
      container.read(unauthorizedEventProvider.notifier).state++;
      await settle();
      await settle();
      expect(container.read(authSessionProvider).isGuest, isTrue);
      expect(tokens.access, isNull);
      expect(storage.getAll(_box), isEmpty);
    });

    test('signIn persists fields and removes null ones', () async {
      storage.boxes[_box] = {AppConstants.authPhotoUrlKey: 'old.png'};
      final n = container.read(authSessionProvider.notifier);
      await n.signIn(const AuthSession(userId: 'u2', email: 'x@y.z'));
      expect(container.read(authSessionProvider).userId, 'u2');
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

    test('signOut clears state, storage and tokens', () async {
      tokens.pending = 'p';
      final n = container.read(authSessionProvider.notifier);
      await n.signIn(const AuthSession(userId: 'u', email: 'e@e.e', name: 'N'));
      await n.signOut();
      expect(container.read(authSessionProvider).isGuest, isTrue);
      expect(storage.getAll(_box), isEmpty);
      expect(tokens.access, isNull);
      expect(tokens.pending, isNull);
    });
  });

  group('AuthGate', () {
    test('markSeen stores the flag', () async {
      await container.read(authGateProvider).markSeen();
      expect(storage.get<bool>(_box, AppConstants.authGateSeenKey), isTrue);
    });
  });

  group('LoginController', () {
    test('wrong credentials: failed, message shown, still guest', () async {
      final o = await container
          .read(loginControllerProvider.notifier)
          .submit(email: 'a@b.c', password: 'p');
      expect(o, LoginOutcome.failed);
      final s = container.read(loginControllerProvider);
      expect(s.isSubmitting, isFalse);
      expect(s.errorMessage, 'Invalid credentials');
      expect(container.read(authSessionProvider).isGuest, isTrue);
      expect(storage.get<bool>(_box, AppConstants.authGateSeenKey), isNull);
    });

    test('verified account signs in and marks the gate', () async {
      repo.loginResult = const Success(verifiedUser);
      final o = await container
          .read(loginControllerProvider.notifier)
          .submit(email: 'a@b.c', password: 'password1');
      expect(o, LoginOutcome.signedIn);
      expect(container.read(loginControllerProvider).errorMessage, isNull);
      expect(container.read(authSessionProvider).userId, 'u1');
      expect(storage.get<bool>(_box, AppConstants.authGateSeenKey), isTrue);
    });

    test(
      'unverified account is NOT signed in; a new OTP is requested',
      () async {
        repo.loginResult = const Success(unverifiedUser);
        final o = await container
            .read(loginControllerProvider.notifier)
            .submit(email: 'a@b.c', password: 'password1');
        expect(o, LoginOutcome.needsVerification);
        expect(container.read(authSessionProvider).isGuest, isTrue);
        expect(storage.get<bool>(_box, AppConstants.authGateSeenKey), isNull);
        expect(repo.resendCalls, 1);
        expect(repo.lastPurpose, OtpPurpose.verifyEmail);
      },
    );
  });

  group('SignupController', () {
    test('failure surfaces message and returns false', () async {
      repo.signupResult = const Error(ServerFailure('Email already in use'));
      final ok = await container
          .read(signupControllerProvider.notifier)
          .submit(name: 'n', email: 'a@b.c', password: 'p');
      expect(ok, isFalse);
      expect(
        container.read(signupControllerProvider).errorMessage,
        'Email already in use',
      );
      expect(container.read(authSessionProvider).isGuest, isTrue);
    });

    test(
      'success returns true but does NOT sign in or mark the gate',
      () async {
        repo.signupResult = const Success(unverifiedUser);
        final ok = await container
            .read(signupControllerProvider.notifier)
            .submit(name: 'N', email: 'a@b.c', password: 'p');
        expect(ok, isTrue);
        expect(container.read(authSessionProvider).isGuest, isTrue);
        expect(storage.get<bool>(_box, AppConstants.authGateSeenKey), isNull);
      },
    );

    test('clearError drops a previous error', () async {
      repo.signupResult = const Error(ServerFailure('boom'));
      final n = container.read(signupControllerProvider.notifier);
      await n.submit(name: 'n', email: 'a@b.c', password: 'p');
      n.clearError();
      expect(container.read(signupControllerProvider).errorMessage, isNull);
    });
  });

  group('ForgotPasswordController', () {
    test('success returns true without error', () async {
      final ok = await container
          .read(forgotPasswordControllerProvider.notifier)
          .sendResetCode(email: 'a@b.c');
      expect(ok, isTrue);
      expect(
        container.read(forgotPasswordControllerProvider).isSubmitting,
        isFalse,
      );
      expect(repo.lastEmail, 'a@b.c');
    });

    test('failure returns false with message; retry clears it', () async {
      repo.forgotResult = const Error(NetworkFailure());
      final n = container.read(forgotPasswordControllerProvider.notifier);
      expect(await n.sendResetCode(email: 'a@b.c'), isFalse);
      expect(
        container.read(forgotPasswordControllerProvider).errorMessage,
        const NetworkFailure().message,
      );
      repo.forgotResult = const Success(null);
      expect(await n.sendResetCode(email: 'a@b.c'), isTrue);
      expect(
        container.read(forgotPasswordControllerProvider).errorMessage,
        isNull,
      );
    });
  });

  group('ResetPasswordController', () {
    test('success passes email/otp/password through, no sign-in', () async {
      final sub = container.listen(resetPasswordControllerProvider, (_, _) {});
      addTearDown(sub.close);
      final ok = await container
          .read(resetPasswordControllerProvider.notifier)
          .submit(email: 'a@b.c', otp: '1234', newPassword: 'newPassword456');
      expect(ok, isTrue);
      expect(repo.lastReset, (
        email: 'a@b.c',
        otp: '1234',
        newPassword: 'newPassword456',
      ));
      expect(container.read(authSessionProvider).isGuest, isTrue);
    });

    test(
      'invalid code surfaces the server message; clearError works',
      () async {
        final sub = container.listen(
          resetPasswordControllerProvider,
          (_, _) {},
        );
        addTearDown(sub.close);
        repo.resetResult = const Error(
          ServerFailure('Invalid or expired code'),
        );
        final n = container.read(resetPasswordControllerProvider.notifier);
        expect(
          await n.submit(email: 'a@b.c', otp: '0000', newPassword: 'x' * 8),
          isFalse,
        );
        expect(
          container.read(resetPasswordControllerProvider).errorMessage,
          'Invalid or expired code',
        );
        n.clearError();
        expect(
          container.read(resetPasswordControllerProvider).errorMessage,
          isNull,
        );
      },
    );
  });

  group('DeleteAccountController', () {
    test('success signs the user out', () async {
      await container
          .read(authSessionProvider.notifier)
          .signIn(const AuthSession(userId: 'u', email: 'e@e.e'));
      final ok = await container
          .read(deleteAccountControllerProvider.notifier)
          .delete();
      expect(ok, isTrue);
      expect(container.read(authSessionProvider).isGuest, isTrue);
      expect(tokens.access, isNull);
    });

    test('failure keeps the user signed in and reports why', () async {
      await container
          .read(authSessionProvider.notifier)
          .signIn(const AuthSession(userId: 'u', email: 'e@e.e'));
      repo.deleteResult = const Error(NetworkFailure());
      final ok = await container
          .read(deleteAccountControllerProvider.notifier)
          .delete();
      expect(ok, isFalse);
      expect(container.read(authSessionProvider).isAuthenticated, isTrue);
      expect(
        container.read(deleteAccountControllerProvider).errorMessage,
        const NetworkFailure().message,
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
    test('10-minute countdown keeps Resend disabled until it ends', () {
      fakeAsync((async) {
        final sub = container.listen(otpControllerProvider, (_, _) {});
        expect(
          container.read(otpControllerProvider).resendCooldownSeconds,
          600,
        );
        expect(container.read(otpControllerProvider).canResend, isFalse);
        async.elapse(const Duration(minutes: 9, seconds: 59));
        expect(container.read(otpControllerProvider).resendCooldownSeconds, 1);
        expect(container.read(otpControllerProvider).canResend, isFalse);
        async.elapse(const Duration(seconds: 1));
        expect(container.read(otpControllerProvider).resendCooldownSeconds, 0);
        expect(container.read(otpControllerProvider).canResend, isTrue);
        sub.close();
      });
    });

    test('resend after countdown calls repo with purpose, restarts it', () {
      fakeAsync((async) {
        final sub = container.listen(otpControllerProvider, (_, _) {});
        async.elapse(const Duration(minutes: 10, seconds: 1));
        container
            .read(otpControllerProvider.notifier)
            .resend(email: 'a@b.c', purpose: OtpPurpose.resetPassword);
        async.flushMicrotasks();
        expect(repo.resendCalls, 1);
        expect(repo.lastPurpose, OtpPurpose.resetPassword);
        expect(
          container.read(otpControllerProvider).resendCooldownSeconds,
          600,
        );
        expect(container.read(otpControllerProvider).isResending, isFalse);
        sub.close();
      });
    });

    test('resend failure leaves it available and sets the error', () {
      fakeAsync((async) {
        repo.resendResult = const Error(NetworkFailure());
        final sub = container.listen(otpControllerProvider, (_, _) {});
        async.elapse(const Duration(minutes: 10, seconds: 1));
        container.read(otpControllerProvider.notifier).resend(email: 'a@b.c');
        async.flushMicrotasks();
        final s = container.read(otpControllerProvider);
        expect(s.errorMessage, const NetworkFailure().message);
        expect(s.canResend, isTrue);
        sub.close();
      });
    });

    test('resend is a no-op during the countdown', () async {
      final sub = container.listen(otpControllerProvider, (_, _) {});
      addTearDown(sub.close);
      await container
          .read(otpControllerProvider.notifier)
          .resend(email: 'a@b.c');
      expect(repo.resendCalls, 0);
    });

    test('verify success signs in and returns true', () async {
      final sub = container.listen(otpControllerProvider, (_, _) {});
      addTearDown(sub.close);
      repo.verifyResult = const Success(AuthSession(userId: 'v1'));
      final ok = await container
          .read(otpControllerProvider.notifier)
          .verify(email: 'a@b.c', code: '1234');
      expect(ok, isTrue);
      expect(container.read(otpControllerProvider).isSubmitting, isFalse);
      expect(container.read(authSessionProvider).userId, 'v1');
      expect(storage.get<bool>(_box, AppConstants.authGateSeenKey), isTrue);
    });

    test(
      'verify failure sets error, stays guest; clearError removes it',
      () async {
        final sub = container.listen(otpControllerProvider, (_, _) {});
        addTearDown(sub.close);
        repo.verifyResult = const Error(
          ServerFailure('Invalid or expired code'),
        );
        final n = container.read(otpControllerProvider.notifier);
        expect(await n.verify(email: 'a@b.c', code: '0000'), isFalse);
        expect(container.read(authSessionProvider).isGuest, isTrue);
        expect(
          container.read(otpControllerProvider).errorMessage,
          'Invalid or expired code',
        );
        n.clearError();
        expect(container.read(otpControllerProvider).errorMessage, isNull);
      },
    );
  });
}
