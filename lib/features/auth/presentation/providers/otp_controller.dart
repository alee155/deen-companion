import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/usecase/usecase.dart';
import '../../domain/entities/otp_purpose.dart';
import 'auth_gate_provider.dart';
import 'auth_providers.dart';
import 'auth_session_provider.dart';

class OtpState {
  final bool isSubmitting;
  final bool isResending;
  final String? errorMessage;
  final int resendCooldownSeconds;

  const OtpState({
    this.isSubmitting = false,
    this.isResending = false,
    this.errorMessage,
    this.resendCooldownSeconds = 0,
  });

  bool get canResend => !isResending && resendCooldownSeconds == 0;

  /// [errorMessage] is preserved by default (unlike the other fields, it has
  /// no natural "unchanged" value to fall back to) — pass [clearError] to
  /// drop it instead of a new one.
  OtpState copyWith({
    bool? isSubmitting,
    bool? isResending,
    String? errorMessage,
    bool clearError = false,
    int? resendCooldownSeconds,
  }) {
    return OtpState(
      isSubmitting: isSubmitting ?? this.isSubmitting,
      isResending: isResending ?? this.isResending,
      errorMessage: clearError
          ? errorMessage
          : (errorMessage ?? this.errorMessage),
      resendCooldownSeconds:
          resendCooldownSeconds ?? this.resendCooldownSeconds,
    );
  }
}

class OtpController extends AutoDisposeNotifier<OtpState> {
  /// OTPs expire after 10 minutes, so Resend stays locked for that long.
  static const resendCooldown = 600;

  Timer? _ticker;

  @override
  OtpState build() {
    ref.onDispose(() => _ticker?.cancel());
    _startCooldown();
    return const OtpState(resendCooldownSeconds: resendCooldown);
  }

  void clearError() {
    if (state.errorMessage != null) {
      state = state.copyWith(clearError: true);
    }
  }

  void _startCooldown() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      final remaining = state.resendCooldownSeconds - 1;
      if (remaining <= 0) {
        timer.cancel();
        state = state.copyWith(resendCooldownSeconds: 0);
      } else {
        state = state.copyWith(resendCooldownSeconds: remaining);
      }
    });
  }

  /// Verifies the OTP and, only on success, completes the sign-in. Returns
  /// true once the user is signed in.
  Future<bool> verify({required String email, required String code}) async {
    if (state.isSubmitting) return false;
    state = state.copyWith(isSubmitting: true, clearError: true);
    final result = await ref
        .read(authRepositoryProvider)
        .verifyOtp(email: email, code: code);
    switch (result) {
      case Success(:final data):
        await ref.read(authSessionProvider.notifier).signIn(data);
        await ref.read(authGateProvider).markSeen();
        state = state.copyWith(isSubmitting: false);
        return true;
      case Error(:final failure):
        state = state.copyWith(
          isSubmitting: false,
          errorMessage: failure.message,
        );
        return false;
    }
  }

  /// Requests a fresh OTP and restarts the 10-minute countdown. Also used by
  /// the reset-password screen (with [OtpPurpose.resetPassword]).
  Future<void> resend({
    required String email,
    OtpPurpose purpose = OtpPurpose.verifyEmail,
  }) async {
    if (!state.canResend) return;
    state = state.copyWith(isResending: true, clearError: true);
    final result = await ref
        .read(authRepositoryProvider)
        .resendOtp(email: email, purpose: purpose);
    var succeeded = false;
    state = result.when(
      success: (_) {
        succeeded = true;
        return state.copyWith(
          isResending: false,
          resendCooldownSeconds: resendCooldown,
        );
      },
      failure: (failure) =>
          state.copyWith(isResending: false, errorMessage: failure.message),
    );
    if (succeeded) _startCooldown();
  }
}

final otpControllerProvider =
    NotifierProvider.autoDispose<OtpController, OtpState>(OtpController.new);
