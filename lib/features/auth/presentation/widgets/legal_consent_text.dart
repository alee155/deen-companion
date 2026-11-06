import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';

/// "By continuing, you agree to our Terms and Privacy Policy", with both names
/// opening the hosted pages in the browser. [prefix] words the first part for
/// the screen it is on.
class LegalConsentText extends StatefulWidget {
  final String prefix;

  /// Opens [url]. Tests replace it; the default launches the browser.
  final Future<void> Function(String url)? onOpen;

  const LegalConsentText({
    super.key,
    this.prefix = 'By continuing, you agree to our ',
    this.onOpen,
  });

  @override
  State<LegalConsentText> createState() => _LegalConsentTextState();
}

class _LegalConsentTextState extends State<LegalConsentText> {
  late final TapGestureRecognizer _terms;
  late final TapGestureRecognizer _privacy;

  @override
  void initState() {
    super.initState();
    _terms = TapGestureRecognizer()
      ..onTap = () => _open(AppConstants.termsAndConditionsUrl);
    _privacy = TapGestureRecognizer()
      ..onTap = () => _open(AppConstants.privacyPolicyUrl);
  }

  @override
  void dispose() {
    _terms.dispose();
    _privacy.dispose();
    super.dispose();
  }

  Future<void> _open(String url) async {
    final custom = widget.onOpen;
    if (custom != null) return custom(url);
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    TextStyle link() =>
        TextStyle(color: AppColors.emeraldInk, fontWeight: FontWeight.w700);
    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: TextStyle(
          fontSize: 11.5.sp,
          color: AppColors.textMuted,
          height: 1.4,
        ),
        children: [
          TextSpan(text: widget.prefix),
          TextSpan(text: 'Terms', style: link(), recognizer: _terms),
          const TextSpan(text: ' and '),
          TextSpan(text: 'Privacy Policy', style: link(), recognizer: _privacy),
        ],
      ),
    );
  }
}
