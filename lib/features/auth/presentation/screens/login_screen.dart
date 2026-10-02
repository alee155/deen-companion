import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/motion/motion.dart';
import '../../../../core/theme/app_colors.dart';
import '../providers/login_controller.dart';
import '../widgets/auth_icon_badge.dart';
import '../widgets/auth_top_header.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/google_button.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  String? _emailError;
  String? _passwordError;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    setState(() {
      _emailError = email.isEmpty
          ? 'Enter your email'
          : (!email.contains('@') || !email.contains('.'))
          ? 'Enter a valid email'
          : null;
      _passwordError = password.isEmpty ? 'Enter your password' : null;
    });
    if (_emailError != null || _passwordError != null) return;

    // TODO(auth-backend): AuthRepository.login is a stub until the real
    // API/flow is provided — this surfaces "coming soon" via the listener
    // below rather than pretending to sign the user in.
    ref
        .read(loginControllerProvider.notifier)
        .submit(email: email, password: password);
  }

  @override
  Widget build(BuildContext context) {
    final seq = RevealSequence();
    final state = ref.watch(loginControllerProvider);

    ref.listen(loginControllerProvider, (previous, next) {
      if (next.errorMessage != null &&
          next.errorMessage != previous?.errorMessage) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(next.errorMessage!)));
      }
    });

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
              imagePath: 'assets/images/slider_1.jpg',
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
                            'Welcome Back',
                            style: TextStyle(
                              fontSize: 26.sp,
                              fontWeight: FontWeight.bold,
                              color: AppColors.inkText,
                            ),
                          ).slideIn(RevealDirection.start, delay: seq.next()),
                          SizedBox(height: 8.h),
                          Text(
                            'Login to continue your journey',
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
                    SizedBox(height: 30.h),

                    CustomTextField(
                      controller: _emailController,
                      label: 'Email',
                      hint: 'Enter your email',
                      prefixIcon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      errorText: _emailError,
                    ).slideIn(RevealDirection.start, delay: seq.next()),
                    SizedBox(height: 18.h),

                    CustomTextField(
                      controller: _passwordController,
                      label: 'Password',
                      hint: 'Enter your password',
                      prefixIcon: Icons.lock_outline,
                      isPassword: true,
                      errorText: _passwordError,
                    ).slideIn(RevealDirection.end, delay: seq.next()),
                    SizedBox(height: 8.h),

                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => context.push('/forgot-password'),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          'Forgot Password?',
                          style: TextStyle(
                            color: AppColors.emeraldInk,
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ).slideIn(RevealDirection.topEnd, delay: seq.next()),
                    SizedBox(height: 20.h),

                    SizedBox(
                      height: 52.h,
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
                                'Login',
                                style: TextStyle(
                                  fontSize: 17.sp,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ).slideIn(RevealDirection.bottom, delay: seq.next()),
                    SizedBox(height: 22.h),

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
                    ).slideIn(RevealDirection.bottomEnd, delay: seq.next()),
                    SizedBox(height: 22.h),

                    GoogleButton(
                      onPressed: () {},
                    ).slideIn(RevealDirection.bottomStart, delay: seq.next()),
                    SizedBox(height: 25.h),

                    Center(
                      child: RichText(
                        text: TextSpan(
                          style: TextStyle(
                            fontSize: 14.sp,
                            color: AppColors.textSecondary,
                          ),
                          children: [
                            const TextSpan(text: "Don't have an account? "),
                            TextSpan(
                              text: 'Sign Up',
                              style: TextStyle(
                                color: AppColors.emeraldInk,
                                fontWeight: FontWeight.bold,
                              ),
                              recognizer: TapGestureRecognizer()
                                ..onTap = () =>
                                    context.pushReplacement('/signup'),
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
