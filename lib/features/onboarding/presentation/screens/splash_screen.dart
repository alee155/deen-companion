import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../ads/presentation/providers/app_open_ad_manager.dart';

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
    final onboardingCompleted =
        storage.get<bool>(
          AppConstants.settingsBoxName,
          AppConstants.onboardingCompletedKey,
        ) ??
        false;
    final permissionFlowSeen =
        storage.get<bool>(
          AppConstants.settingsBoxName,
          AppConstants.permissionFlowSeenKey,
        ) ??
        false;

    // Ensure the splash is visible for at least a moment even on a fast
    // device — avoids an unpleasant instant flash-and-gone.
    final elapsed = DateTime.now().difference(started);
    if (elapsed < AppConstants.splashMinDuration) {
      await Future.delayed(AppConstants.splashMinDuration - elapsed);
    }

    if (!mounted) return;
    if (!onboardingCompleted) {
      context.go('/onboarding');
    } else if (!permissionFlowSeen) {
      // Permissions are asked before the first real screen, so Home never
      // has to render a failure state on a cold install.
      context.go('/permissions');
    } else {
      // This is the one branch that represents a genuine cold start for a
      // returning user — exactly where an App Open ad belongs. The
      // lifecycle-based path in AppOpenAdManager only ever fires on a
      // background→foreground resume, which a fresh launch is not, so it
      // can never show one here on its own. Fire-and-forget: the ad (if
      // any is ready) shows on top of Home once it renders, but never
      // blocks getting there.
      ref.read(appOpenAdManagerProvider).maybeShowOnColdStart();
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.parchment,
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
