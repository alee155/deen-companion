import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_providers.dart';

class ResetPasswordState {
  final bool isSubmitting;
  final String? errorMessage;

  const ResetPasswordState({this.isSubmitting = false, this.errorMessage});
}

/// Step 2 of a password reset: OTP + new password. Doesn't sign anyone in —
/// the user logs in with the new password afterwards.
class ResetPasswordController extends AutoDisposeNotifier<ResetPasswordState> {
  @override
  ResetPasswordState build() => const ResetPasswordState();

  void clearError() {
    if (state.errorMessage != null) state = const ResetPasswordState();
  }

  Future<bool> submit({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    if (state.isSubmitting) return false;
    state = const ResetPasswordState(isSubmitting: true);
    final result = await ref
        .read(authRepositoryProvider)
        .resetPassword(email: email, otp: otp, newPassword: newPassword);
    var succeeded = false;
    state = result.when(
      success: (_) {
        succeeded = true;
        return const ResetPasswordState();
      },
      failure: (f) => ResetPasswordState(errorMessage: f.message),
    );
    return succeeded;
  }
}

final resetPasswordControllerProvider =
    NotifierProvider.autoDispose<ResetPasswordController, ResetPasswordState>(
      ResetPasswordController.new,
    );
