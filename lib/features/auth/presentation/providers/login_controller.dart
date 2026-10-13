import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/usecase/usecase.dart';
import '../../domain/entities/otp_purpose.dart';
import 'auth_gate_provider.dart';
import 'auth_providers.dart';
import 'auth_session_provider.dart';

class LoginState {
  final bool isSubmitting;
  final String? errorMessage;

  const LoginState({this.isSubmitting = false, this.errorMessage});
}

enum LoginOutcome {
  /// Credentials were wrong / request failed — see [LoginState.errorMessage].
  failed,

  /// Verified account: the session is now active.
  signedIn,

  /// Correct credentials but the email isn't verified yet: not signed in; a
  /// fresh OTP was requested and the caller should show OTP verification.
  needsVerification,
}

/// Owns Login's submit/loading/error state. Field values themselves live in
/// plain `TextEditingController`s on the screen.
class LoginController extends Notifier<LoginState> {
  @override
  LoginState build() => const LoginState();

  Future<LoginOutcome> submit({
    required String email,
    required String password,
  }) async {
    if (state.isSubmitting) return LoginOutcome.failed;
    state = const LoginState(isSubmitting: true);
    final repo = ref.read(authRepositoryProvider);
    final result = await repo.login(email: email, password: password);
    switch (result) {
      case Success(:final data):
        if (data.isEmailVerified) {
          await ref.read(authSessionProvider.notifier).signIn(data.toSession());
          await ref.read(authGateProvider).markSeen();
          state = const LoginState();
          return LoginOutcome.signedIn;
        }
        // Any earlier code may have expired, so send a new one. If this
        // fails the OTP screen still offers Resend.
        await repo.resendOtp(email: email, purpose: OtpPurpose.verifyEmail);
        state = const LoginState();
        return LoginOutcome.needsVerification;
      case Error(:final failure):
        state = LoginState(errorMessage: failure.message);
        return LoginOutcome.failed;
    }
  }
}

final loginControllerProvider = NotifierProvider<LoginController, LoginState>(
  LoginController.new,
);
