import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/motion/motion.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/otp_purpose.dart';
import '../providers/otp_controller.dart';
import '../providers/reset_password_controller.dart';
import '../widgets/auth_icon_badge.dart';
import '../widgets/auth_top_header.dart';
import '../widgets/custom_text_field.dart';

/// Step 2 of "Forgot password": enter the emailed 4-digit code and a new
/// password. Reuses the OTP controller purely for the 10-minute resend
/// countdown and the resend call (with the `reset_password` purpose).
class ResetPasswordScreen extends ConsumerStatefulWidget {
  final String email;

  const ResetPasswordScreen({super.key, required this.email});

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  static const _otpLength = 4;
  static const _minPasswordLength = 8;

  final _otpController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  String? _otpError;
  String? _passwordError;
  String? _confirmError;

  @override
  void dispose() {
    _otpController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  static String _mmss(int seconds) =>
      '${(seconds ~/ 60).toString().padLeft(2, '0')}:'
      '${(seconds % 60).toString().padLeft(2, '0')}';

  Future<void> _submit() async {
    final otp = _otpController.text.trim();
    final password = _passwordController.text;
    setState(() {
      _otpError = otp.length != _otpLength
          ? 'Enter the $_otpLength-digit code'
          : null;
      _passwordError = password.length < _minPasswordLength
          ? 'Use at least $_minPasswordLength characters'
          : null;
      _confirmError = _confirmController.text != password
          ? "Passwords don't match"
          : null;
    });
    if (_otpError != null || _passwordError != null || _confirmError != null) {
      return;
    }

    FocusScope.of(context).unfocus();
    final ok = await ref
        .read(resetPasswordControllerProvider.notifier)
        .submit(email: widget.email, otp: otp, newPassword: password);
    if (!mounted || !ok) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.success,
        content: const Text('Password updated. Log in with your new password.'),
      ),
    );
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final seq = RevealSequence();
    final state = ref.watch(resetPasswordControllerProvider);
    final otp = ref.watch(otpControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.parchment,
      body: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 200.h,
            child: AuthTopHeader(
              imagePath: 'assets/images/slider_4.jpg',
              onBack: () => context.pop(),
            ),
          ),
          Positioned(
            top: 165.h,
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.parchment,
                borderRadius: BorderRadius.vertical(top: Radius.circular(30.r)),
              ),
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(24.w, 0, 24.w, 24.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const AuthIconBadge().slideIn(
                      RevealDirection.topStart,
                      distance: 18,
                    ),
                    Transform.translate(
                      offset: Offset(0, -15.h),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Reset Password',
                            style: TextStyle(
                              fontSize: 26.sp,
                              fontWeight: FontWeight.bold,
                              color: AppColors.inkText,
                            ),
                          ).slideIn(RevealDirection.start, delay: seq.next()),
                          SizedBox(height: 6.h),
                          Text(
                            'Enter the code we emailed to ${widget.email} '
                            'and choose a new password.',
                            style: TextStyle(
                              fontSize: 14.sp,
                              height: 1.5,
                              color: AppColors.textSecondary,
                            ),
                          ).slideIn(
                            RevealDirection.bottomStart,
                            delay: seq.next(),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 10.h),
                    CustomTextField(
                      controller: _otpController,
                      label: 'Verification code',
                      hint: 'Enter the $_otpLength-digit code',
                      prefixIcon: Icons.pin_outlined,
                      keyboardType: TextInputType.number,
                      errorText: _otpError,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(_otpLength),
                      ],
                    ).slideIn(RevealDirection.start, delay: seq.next()),
                    SizedBox(height: 10.h),
                    CustomTextField(
                      controller: _passwordController,
                      label: 'New password',
                      hint: 'At least $_minPasswordLength characters',
                      prefixIcon: Icons.lock_outline,
                      isPassword: true,
                      errorText: _passwordError,
                    ).slideIn(RevealDirection.end, delay: seq.next()),
                    SizedBox(height: 10.h),
                    CustomTextField(
                      controller: _confirmController,
                      label: 'Confirm password',
                      hint: 'Re-enter the new password',
                      prefixIcon: Icons.lock_outline,
                      isPassword: true,
                      errorText: _confirmError,
                    ).slideIn(RevealDirection.bottom, delay: seq.next()),
                    SizedBox(height: 10.h),
                    if ((state.errorMessage ?? otp.errorMessage) != null) ...[
                      Text(
                        state.errorMessage ?? otp.errorMessage!,
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: AppColors.error,
                        ),
                      ),
                      SizedBox(height: 10.h),
                    ],
                    SizedBox(
                      height: 50.h,
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: state.isSubmitting ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.emeraldInk,
                          foregroundColor: AppColors.onEmeraldInk,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30.r),
                          ),
                        ),
                        child: state.isSubmitting
                            ? SizedBox(
                                height: 20.h,
                                width: 20.h,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.onEmeraldInk,
                                ),
                              )
                            : Text(
                                'Reset Password',
                                style: TextStyle(
                                  fontSize: 17.sp,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ).slideIn(RevealDirection.bottomEnd, delay: seq.next()),
                    SizedBox(height: 14.h),
                    Center(
                      child: Column(
                        children: [
                          Text(
                            otp.resendCooldownSeconds > 0
                                ? 'Code expires in '
                                      '${_mmss(otp.resendCooldownSeconds)}'
                                : 'Your code has expired. Request a new one.',
                            style: TextStyle(
                              fontSize: 13.sp,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          TextButton(
                            // Disabled while the 10-minute countdown runs.
                            onPressed: otp.canResend && !state.isSubmitting
                                ? () {
                                    ref
                                        .read(otpControllerProvider.notifier)
                                        .resend(
                                          email: widget.email,
                                          purpose: OtpPurpose.resetPassword,
                                        );
                                  }
                                : null,
                            child: Text(
                              otp.isResending ? 'Resending…' : 'Resend code',
                              style: TextStyle(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ).slideIn(RevealDirection.bottom, delay: seq.next()),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
