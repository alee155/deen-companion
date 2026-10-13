import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_providers.dart';

class ForgotPasswordState {
  final bool isSubmitting;
  final String? errorMessage;

  const ForgotPasswordState({this.isSubmitting = false, this.errorMessage});
}

/// Step 1 of a password reset: ask the backend to email a reset code.
class ForgotPasswordController extends Notifier<ForgotPasswordState> {
  @override
  ForgotPasswordState build() => const ForgotPasswordState();

  /// Returns true when the request was accepted (the backend answers the same
  /// whether or not the account exists, so this never confirms an account).
  Future<bool> sendResetCode({required String email}) async {
    if (state.isSubmitting) return false;
    state = const ForgotPasswordState(isSubmitting: true);
    final result = await ref
        .read(authRepositoryProvider)
        .forgotPassword(email: email);
    var succeeded = false;
    state = result.when(
      success: (_) {
        succeeded = true;
        return const ForgotPasswordState();
      },
      failure: (failure) => ForgotPasswordState(errorMessage: failure.message),
    );
    return succeeded;
  }
}

final forgotPasswordControllerProvider =
    NotifierProvider<ForgotPasswordController, ForgotPasswordState>(
      ForgotPasswordController.new,
    );
