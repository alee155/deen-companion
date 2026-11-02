import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import 'social_auth_button.dart';

/// "Continue with Google". Not wired up yet: the real flow goes into
/// [onPressed] later.
class GoogleButton extends StatelessWidget {
  final VoidCallback onPressed;

  const GoogleButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SocialAuthButton(
      label: 'Continue with Google',
      iconAsset: 'assets/images/icons/google.svg',
      onPressed: onPressed,
      backgroundColor: AppColors.surfaceLight,
      foregroundColor: AppColors.inkText,
      borderColor: AppColors.borderWarm,
    );
  }
}
