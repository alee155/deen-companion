import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/usecase/usecase.dart';
import 'auth_gate_provider.dart';
import 'auth_providers.dart';
import 'auth_session_provider.dart';

class SignupState {
  final bool isSubmitting;
  final String? errorMessage;

  const SignupState({this.isSubmitting = false, this.errorMessage});
}

class SignupController extends Notifier<SignupState> {
  @override
  SignupState build() => const SignupState();

  /// TODO(auth-backend): wired to [AuthRepository.signup], which is a stub
  /// until the real API/flow is provided.
  Future<void> submit({
    required String name,
    required String email,
    required String password,
  }) async {
    state = const SignupState(isSubmitting: true);
    final result = await ref
        .read(authRepositoryProvider)
        .signup(name: name, email: email, password: password);
    switch (result) {
      case Success(:final data):
        await ref.read(authSessionProvider.notifier).signIn(data);
        await ref.read(authGateProvider).markSeen();
        state = const SignupState();
      case Error(:final failure):
        state = SignupState(errorMessage: failure.message);
    }
  }
}

final signupControllerProvider =
    NotifierProvider<SignupController, SignupState>(SignupController.new);
