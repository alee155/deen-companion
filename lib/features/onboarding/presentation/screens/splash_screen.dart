import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/theme/app_colors.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _decideNextRoute();
  }

  Future<void> _decideNextRoute() async {
    final started = DateTime.now();
    final storage = ref.read(localStorageServiceProvider);
    final completed =
        storage.get<bool>(
          AppConstants.settingsBoxName,
          AppConstants.onboardingCompletedKey,
        ) ??
        false;

    // Ensure the splash is visible for at least a moment even on a fast
    // device — avoids an unpleasant instant flash-and-gone.
    final elapsed = DateTime.now().difference(started);
    if (elapsed < AppConstants.splashMinDuration) {
      await Future.delayed(AppConstants.splashMinDuration - elapsed);
    }

    if (!mounted) return;
    context.go(completed ? '/' : '/onboarding');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F1E2),
      body: Stack(
        children: [
          // Center logo
          Positioned(
            left: 20,
            right: 0,
            top: 150.h,
            child: Image.asset(
              'assets/images/splash.png',
              width: 340.w,
              height: 340.h,
              fit: BoxFit.contain,
            ),
          ),

          // Bottom image
          Positioned(
            left: 0,
            right: 0,
            bottom: -8.h,
            child: Image.asset(
              'assets/images/masjid.png',
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
        ],
      ),
    );
  }
}
