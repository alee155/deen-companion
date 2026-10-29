import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/usecase/usecase.dart';
import '../../domain/entities/gender.dart';
import 'auth_providers.dart';

class SignupState {
  final bool isSubmitting;
  final String? errorMessage;

  const SignupState({this.isSubmitting = false, this.errorMessage});
}

class SignupController extends Notifier<SignupState> {
  @override
  SignupState build() => const SignupState();

  void clearError() {
    if (state.errorMessage != null) state = const SignupState();
  }

  /// Registers the account. Returns true when the account was created and an
  /// OTP is on its way — the caller then moves on to OTP verification. This
  /// deliberately does NOT sign the user in: the session is only established
  /// after the OTP is verified (see [OtpController.verify]).
  Future<bool> submit({
    required String name,
    required String email,
    required String password,
    required Gender gender,
  }) async {
    if (state.isSubmitting) return false;
    state = const SignupState(isSubmitting: true);
    final result = await ref
        .read(authRepositoryProvider)
        .signup(name: name, email: email, password: password, gender: gender);
    switch (result) {
      case Success():
        state = const SignupState();
        return true;
      case Error(:final failure):
        state = SignupState(errorMessage: failure.message);
        return false;
    }
  }
}

final signupControllerProvider =
    NotifierProvider<SignupController, SignupState>(SignupController.new);
