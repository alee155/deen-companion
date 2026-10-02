import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/motion/motion.dart';
import '../../../../core/theme/app_colors.dart';
import '../providers/forgot_password_controller.dart';
import '../widgets/auth_icon_badge.dart';
import '../widgets/auth_top_header.dart';
import '../widgets/custom_text_field.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@') || !email.contains('.')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid email address')),
      );
      return;
    }

    // TODO(auth-backend): AuthRepository.sendOtp is a stub until the real
    // API/flow is provided. The OTP step is still shown regardless of the
    // stub's result, so the reset flow can be walked end-to-end before then.
    await ref
        .read(forgotPasswordControllerProvider.notifier)
        .sendResetCode(email: email);

    if (!mounted) return;
    context.push('/otp?email=${Uri.encodeQueryComponent(email)}');
  }

  @override
  Widget build(BuildContext context) {
    final seq = RevealSequence();
    final state = ref.watch(forgotPasswordControllerProvider);

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
                    const AuthIconBadge().slideIn(RevealDirection.topStart, distance: 18),

                    Transform.translate(
                      offset: Offset(0, -15.h),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Forgot Password?',
                            style: TextStyle(
                              fontSize: 26.sp,
                              fontWeight: FontWeight.bold,
                              color: AppColors.inkText,
                            ),
                          ).slideIn(RevealDirection.start, delay: seq.next()),
                          SizedBox(height: 8.h),
                          Text(
                            "No worries! Enter the email linked to your "
                            "account and we'll send you a 4-digit code to "
                            "reset your password.",
                            style: TextStyle(
                              fontSize: 14.sp,
                              color: AppColors.textSecondary,
                              height: 1.5,
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
                      controller: _emailController,
                      label: 'Email',
                      hint: 'Enter your email',
                      prefixIcon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                    ).slideIn(RevealDirection.end, delay: seq.next()),
                    SizedBox(height: 18.h),

                    SizedBox(
                      height: 52.h,
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: state.isSubmitting ? null : _sendCode,
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
                                'Send Reset Code',
                                style: TextStyle(
                                  fontSize: 17.sp,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ).slideIn(RevealDirection.bottom, delay: seq.next()),
                    SizedBox(height: 15.h),

                    Center(
                      child: RichText(
                        text: TextSpan(
                          style: TextStyle(
                            fontSize: 14.sp,
                            color: AppColors.textSecondary,
                          ),
                          children: [
                            const TextSpan(text: 'Remembered your password? '),
                            TextSpan(
                              text: 'Login',
                              style: TextStyle(
                                color: AppColors.emeraldInk,
                                fontWeight: FontWeight.bold,
                              ),
                              recognizer: TapGestureRecognizer()
                                ..onTap = () => context.pop(),
                            ),
                          ],
                        ),
                      ),
                    ).slideIn(RevealDirection.bottomStart, delay: seq.next()),
                    SizedBox(height: 30.h),

                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(14.w),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(14.r),
                        border: Border.all(color: AppColors.borderWarm),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            size: 18.sp,
                            color: AppColors.textMuted,
                          ),
                          SizedBox(width: 10.w),
                          Expanded(
                            child: Text(
                              "Can't find the email? Check your spam folder "
                              "or make sure you typed the address you "
                              "registered with.",
                              style: TextStyle(
                                fontSize: 12.sp,
                                color: AppColors.textSecondary,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ).slideIn(RevealDirection.bottomEnd, delay: seq.next()),
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
