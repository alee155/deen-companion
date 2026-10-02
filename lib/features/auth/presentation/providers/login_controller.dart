import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/usecase/usecase.dart';
import 'auth_gate_provider.dart';
import 'auth_providers.dart';
import 'auth_session_provider.dart';

class LoginState {
  final bool isSubmitting;
  final String? errorMessage;

  const LoginState({this.isSubmitting = false, this.errorMessage});
}

/// Owns Login's submit/loading/error state. Field values themselves live in
/// plain `TextEditingController`s on the screen.
class LoginController extends Notifier<LoginState> {
  @override
  LoginState build() => const LoginState();

  /// TODO(auth-backend): wired to [AuthRepository.login], which is a stub
  /// until the real API/flow is provided — this always surfaces "coming
  /// soon" rather than pretending to succeed.
  Future<void> submit({required String email, required String password}) async {
    state = const LoginState(isSubmitting: true);
    final result = await ref
        .read(authRepositoryProvider)
        .login(email: email, password: password);
    switch (result) {
      case Success(:final data):
        await ref.read(authSessionProvider.notifier).signIn(data);
        await ref.read(authGateProvider).markSeen();
        state = const LoginState();
      case Error(:final failure):
        state = LoginState(errorMessage: failure.message);
    }
  }
}

final loginControllerProvider = NotifierProvider<LoginController, LoginState>(
  LoginController.new,
);
