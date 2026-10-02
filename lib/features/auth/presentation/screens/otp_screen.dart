import 'package:flutter/material.dart';
import 'package:deen_companion/core/motion/motion.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../providers/otp_controller.dart';
import '../widgets/auth_icon_badge.dart';
import '../widgets/auth_top_header.dart';

class OtpScreen extends ConsumerStatefulWidget {
  final String email;

  const OtpScreen({super.key, required this.email});

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  static const _otpLength = 4;

  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _focusNodes;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(_otpLength, (_) => TextEditingController());
    _focusNodes = List.generate(_otpLength, (_) => FocusNode());
  }

  String get _otpCode => _controllers.map((c) => c.text).join();

  void _onChanged(int index, String value) {
    ref.read(otpControllerProvider.notifier).clearError();

    if (value.isNotEmpty) {
      if (index < _otpLength - 1) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus();
      }
    } else if (index > 0) {
      _focusNodes[index - 1].requestFocus();
    }

    if (_otpCode.length == _otpLength) {
      FocusScope.of(context).unfocus();
      ref
          .read(otpControllerProvider.notifier)
          .verify(email: widget.email, code: _otpCode);
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final seq = RevealSequence();
    final state = ref.watch(otpControllerProvider);
    final hasError = state.errorMessage != null;

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
              imagePath: 'assets/images/slider_3.jpg',
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
                            'Verify Your Email',
                            style: TextStyle(
                              fontSize: 26.sp,
                              fontWeight: FontWeight.bold,
                              color: AppColors.inkText,
                            ),
                          ).slideIn(RevealDirection.start, delay: seq.next()),
                          SizedBox(height: 10.h),
                          RichText(
                            text: TextSpan(
                              style: TextStyle(
                                fontSize: 14.sp,
                                color: AppColors.textSecondary,
                                height: 1.5,
                              ),
                              children: [
                                const TextSpan(
                                  text:
                                      'Enter the 4-digit verification code we sent to ',
                                ),
                                TextSpan(
                                  text: widget.email,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.inkText,
                                  ),
                                ),
                              ],
                            ),
                          ).slideIn(
                            RevealDirection.bottomStart,
                            delay: seq.next(),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 30.h),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(_otpLength, (index) {
                        return SizedBox(
                          height: 68.h,
                          width: 68.h,
                          child: TextField(
                            controller: _controllers[index],
                            focusNode: _focusNodes[index],
                            textAlign: TextAlign.center,
                            keyboardType: TextInputType.number,
                            maxLength: 1,
                            enabled: !state.isSubmitting,
                            style: TextStyle(
                              fontSize: 24.sp,
                              fontWeight: FontWeight.bold,
                              color: AppColors.inkText,
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            decoration: InputDecoration(
                              counterText: '',
                              filled: true,
                              fillColor: AppColors.surfaceLight,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16.r),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16.r),
                                borderSide: BorderSide(
                                  color: hasError
                                      ? AppColors.error
                                      : Colors.transparent,
                                  width: 1.2.w,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16.r),
                                borderSide: BorderSide(
                                  color: AppColors.emeraldInk,
                                  width: 1.5.w,
                                ),
                              ),
                            ),
                            onChanged: (value) => _onChanged(index, value),
                          ),
                        ).slideIn(
                          const [
                            RevealDirection.start,
                            RevealDirection.top,
                            RevealDirection.bottom,
                            RevealDirection.end,
                          ][index % 4],
                          delay: seq.next(),
                          distance: 18,
                        );
                      }),
                    ),

                    if (hasError) ...[
                      SizedBox(height: 10.h),
                      Text(
                        state.errorMessage!,
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: AppColors.error,
                        ),
                      ),
                    ],
                    if (state.isSubmitting) ...[
                      SizedBox(height: 14.h),
                      Row(
                        children: [
                          SizedBox(
                            height: 16.h,
                            width: 16.h,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.emeraldInk,
                            ),
                          ),
                          SizedBox(width: 10.w),
                          Text(
                            'Verifying…',
                            style: TextStyle(
                              fontSize: 13.sp,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                    SizedBox(height: 22.h),

                    Center(
                      child: state.resendCooldownSeconds > 0
                          ? RichText(
                              text: TextSpan(
                                style: TextStyle(
                                  fontSize: 14.sp,
                                  color: AppColors.textSecondary,
                                ),
                                children: [
                                  const TextSpan(
                                    text: "Didn't receive the code? ",
                                  ),
                                  TextSpan(
                                    text:
                                        'Resend in ${state.resendCooldownSeconds}s',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : Pressable(
                              onTap: state.isResending
                                  ? null
                                  : () => ref
                                        .read(otpControllerProvider.notifier)
                                        .resend(email: widget.email),
                              child: RichText(
                                text: TextSpan(
                                  style: TextStyle(
                                    fontSize: 14.sp,
                                    color: AppColors.textSecondary,
                                  ),
                                  children: [
                                    const TextSpan(
                                      text: "Didn't receive the code? ",
                                    ),
                                    TextSpan(
                                      text: state.isResending
                                          ? 'Resending…'
                                          : 'Resend',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.emeraldInk,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                    ).slideIn(RevealDirection.bottomStart, delay: seq.next()),
                    SizedBox(height: 18.h),

                    Center(
                      child: Pressable(
                        onTap: () => context.pop(),
                        child: Text(
                          'Wrong email? Go back and edit',
                          style: TextStyle(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textMuted,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ).slideIn(RevealDirection.bottomEnd, delay: seq.next()),
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
                            Icons.shield_outlined,
                            size: 18.sp,
                            color: AppColors.textMuted,
                          ),
                          SizedBox(width: 10.w),
                          Expanded(
                            child: Text(
                              'For your security, this code expires in 10 '
                              'minutes and can only be used once.',
                              style: TextStyle(
                                fontSize: 12.sp,
                                color: AppColors.textSecondary,
                                height: 1.4,
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
