import 'package:flutter/material.dart';

import 'social_auth_button.dart';

/// "Continue with Apple": a black button with a white mark, as Apple's
/// guidelines ask for. Not wired up yet: the real flow goes into [onPressed]
/// later.
class AppleButton extends StatelessWidget {
  final VoidCallback onPressed;

  const AppleButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SocialAuthButton(
      label: 'Continue with Apple',
      iconAsset: 'assets/images/icons/apple.svg',
      onPressed: onPressed,
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
      tintIcon: true,
    );
  }
}
