import 'package:flutter/material.dart';

import 'social_auth_button.dart';

/// "Continue with Apple": a black button with a white mark, as Apple's
/// guidelines ask for. A null [onPressed] disables it.
class AppleButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool loading;

  const AppleButton({super.key, required this.onPressed, this.loading = false});

  @override
  Widget build(BuildContext context) {
    return SocialAuthButton(
      label: 'Continue with Apple',
      iconAsset: 'assets/images/icons/apple.svg',
      onPressed: onPressed,
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
      tintIcon: true,
      loading: loading,
    );
  }
}
