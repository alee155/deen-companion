import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_providers.dart';

class ForgotPasswordState {
  final bool isSubmitting;
  final String? errorMessage;

  const ForgotPasswordState({this.isSubmitting = false, this.errorMessage});

  ForgotPasswordState copyWith({bool? isSubmitting, String? errorMessage}) {
    return ForgotPasswordState(
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: errorMessage,
    );
  }
}

/// Reuses [AuthRepository.sendOtp] — a reset code is the same "send a code
/// to this email" action as the signup verification step, just entered from
/// a different screen.
class ForgotPasswordController extends Notifier<ForgotPasswordState> {
  @override
  ForgotPasswordState build() => const ForgotPasswordState();

  /// TODO(auth-backend): wired to [AuthRepository.sendOtp], which is a stub
  /// until the real API/flow is provided.
  Future<bool> sendResetCode({required String email}) async {
    state = state.copyWith(isSubmitting: true, errorMessage: null);
    final result = await ref.read(authRepositoryProvider).sendOtp(email: email);
    var succeeded = false;
    state = result.when(
      success: (_) {
        succeeded = true;
        return state.copyWith(isSubmitting: false);
      },
      failure: (failure) =>
          state.copyWith(isSubmitting: false, errorMessage: failure.message),
    );
    return succeeded;
  }
}

final forgotPasswordControllerProvider =
    NotifierProvider<ForgotPasswordController, ForgotPasswordState>(
      ForgotPasswordController.new,
    );
