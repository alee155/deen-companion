import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// The image banner at the top of Login/Signup/OTP, with an optional back
/// button overlaid on it.
class AuthTopHeader extends StatelessWidget {
  final String imagePath;
  final VoidCallback? onBack;

  const AuthTopHeader({super.key, required this.imagePath, this.onBack});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(imagePath, fit: BoxFit.cover),
        Container(color: Colors.black.withValues(alpha: 0.35)),
        if (onBack != null)
          Positioned(
            top: 10.h,
            left: 10.w,
            child: SafeArea(
              bottom: false,
              child: IconButton(
                onPressed: onBack,
                icon: Icon(
                  Icons.arrow_back_ios_new,
                  color: Colors.white,
                  size: 20.sp,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
