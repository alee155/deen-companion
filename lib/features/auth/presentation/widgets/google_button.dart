import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import 'social_auth_button.dart';

/// "Continue with Google". A null [onPressed] disables it.
class GoogleButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool loading;

  const GoogleButton({
    super.key,
    required this.onPressed,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return SocialAuthButton(
      label: 'Continue with Google',
      iconAsset: 'assets/images/icons/google.svg',
      onPressed: onPressed,
      backgroundColor: AppColors.surfaceLight,
      foregroundColor: AppColors.inkText,
      borderColor: AppColors.borderWarm,
      loading: loading,
    );
  }
}
