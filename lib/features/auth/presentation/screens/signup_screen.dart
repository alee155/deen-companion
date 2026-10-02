import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/motion/motion.dart';
import '../../../../core/theme/app_colors.dart';
import '../providers/signup_controller.dart';
import '../widgets/auth_icon_badge.dart';
import '../widgets/auth_top_header.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/google_button.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  String? _nameError;
  String? _emailError;
  String? _passwordError;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    setState(() {
      _nameError = name.isEmpty ? 'Enter your name' : null;
      _emailError = email.isEmpty
          ? 'Enter your email'
          : (!email.contains('@') || !email.contains('.'))
          ? 'Enter a valid email'
          : null;
      _passwordError = password.isEmpty ? 'Create a password' : null;
    });
    if (_nameError != null || _emailError != null || _passwordError != null) {
      return;
    }

    // TODO(auth-backend): AuthRepository.signup is a stub until the real
    // API/flow is provided. The OTP step is still shown regardless of the
    // stub's result, so the flow can be walked end-to-end before then —
    // no account is actually created yet.
    await ref
        .read(signupControllerProvider.notifier)
        .submit(name: name, email: email, password: password);

    if (!mounted) return;
    context.push('/otp?email=${Uri.encodeQueryComponent(email)}');
  }

  @override
  Widget build(BuildContext context) {
    final seq = RevealSequence();
    final state = ref.watch(signupControllerProvider);

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
              imagePath: 'assets/images/slider_2.jpg',
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
                padding: EdgeInsets.fromLTRB(24.w, 0, 24.w, 20.h),
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
                            'Create Account',
                            style: TextStyle(
                              fontSize: 26.sp,
                              fontWeight: FontWeight.bold,
                              color: AppColors.inkText,
                            ),
                          ).slideIn(RevealDirection.start, delay: seq.next()),
                          Text(
                            'Sign up to begin your journey',
                            style: TextStyle(
                              fontSize: 14.sp,
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
                      controller: _nameController,
                      label: 'Full Name',
                      hint: 'Enter your name',
                      prefixIcon: Icons.person_outline,
                      errorText: _nameError,
                    ).slideIn(RevealDirection.start, delay: seq.next()),
                    SizedBox(height: 10.h),

                    CustomTextField(
                      controller: _emailController,
                      label: 'Email',
                      hint: 'Enter your email',
                      prefixIcon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      errorText: _emailError,
                    ).slideIn(RevealDirection.end, delay: seq.next()),
                    SizedBox(height: 10.h),

                    CustomTextField(
                      controller: _passwordController,
                      label: 'Password',
                      hint: 'Create a password',
                      prefixIcon: Icons.lock_outline,
                      isPassword: true,
                      errorText: _passwordError,
                    ).slideIn(RevealDirection.bottom, delay: seq.next()),
                    SizedBox(height: 10.h),

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
                                'Create Account',
                                style: TextStyle(
                                  fontSize: 17.sp,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ).slideIn(RevealDirection.bottomEnd, delay: seq.next()),
                    SizedBox(height: 10.h),

                    Row(
                      children: [
                        Expanded(child: Divider(color: AppColors.borderWarm)),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12.w),
                          child: Text(
                            'or continue with',
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 13.sp,
                            ),
                          ),
                        ),
                        Expanded(child: Divider(color: AppColors.borderWarm)),
                      ],
                    ).slideIn(RevealDirection.bottomStart, delay: seq.next()),
                    SizedBox(height: 10.h),

                    GoogleButton(
                      onPressed: () {},
                    ).slideIn(RevealDirection.end, delay: seq.next()),
                    SizedBox(height: 15.h),

                    Center(
                      child: RichText(
                        text: TextSpan(
                          style: TextStyle(
                            fontSize: 14.sp,
                            color: AppColors.textSecondary,
                          ),
                          children: [
                            const TextSpan(text: 'Already have an account? '),
                            TextSpan(
                              text: 'Login',
                              style: TextStyle(
                                color: AppColors.emeraldInk,
                                fontWeight: FontWeight.bold,
                              ),
                              recognizer: TapGestureRecognizer()
                                ..onTap = () =>
                                    context.pushReplacement('/login'),
                            ),
                          ],
                        ),
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
