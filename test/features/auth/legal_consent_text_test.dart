import 'package:deen_companion/core/constants/app_constants.dart';
import 'package:deen_companion/features/auth/presentation/widgets/legal_consent_text.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

/// Taps the span of [text] inside the one RichText, at its centre.
Future<void> _tapSpan(WidgetTester tester, String text) async {
  final rich = tester.widget<RichText>(find.byType(RichText).first);
  final span = rich.text as TextSpan;
  for (final child in span.children!) {
    if (child is TextSpan && child.text == text) {
      (child.recognizer as TapGestureRecognizer).onTap!();
      return;
    }
  }
  fail('no "$text" link');
}

void main() {
  Future<List<String>> pump(WidgetTester tester, {String? prefix}) async {
    final opened = <String>[];
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, _) => MaterialApp(
          home: Scaffold(
            body: Center(
              child: prefix == null
                  ? LegalConsentText(onOpen: (u) async => opened.add(u))
                  : LegalConsentText(
                      prefix: prefix,
                      onOpen: (u) async => opened.add(u),
                    ),
            ),
          ),
        ),
      ),
    );
    return opened;
  }

  testWidgets('Terms and Privacy Policy open their own hosted pages', (
    tester,
  ) async {
    final opened = await pump(tester);
    await _tapSpan(tester, 'Terms');
    await _tapSpan(tester, 'Privacy Policy');
    expect(opened, [
      'https://legal-sites.dgexpense.com/deen-app/terms_and_conditions.html',
      'https://legal-sites.dgexpense.com/deen-app/privacy_policy.html',
    ]);
    expect(opened, [
      AppConstants.termsAndConditionsUrl,
      AppConstants.privacyPolicyUrl,
    ]);
  });

  testWidgets('the sentence is worded by the screen it is on', (tester) async {
    await pump(tester);
    expect(
      find.textContaining(
        'By continuing, you agree to our',
        findRichText: true,
      ),
      findsOneWidget,
    );
    await pump(tester, prefix: 'By creating an account, you agree to our ');
    expect(
      find.textContaining(
        'By creating an account, you agree to our Terms and Privacy Policy',
        findRichText: true,
      ),
      findsOneWidget,
    );
  });

  test('all four hosted pages are the agreed addresses', () {
    expect(
      AppConstants.privacyPolicyUrl,
      'https://legal-sites.dgexpense.com/deen-app/privacy_policy.html',
    );
    expect(
      AppConstants.termsAndConditionsUrl,
      'https://legal-sites.dgexpense.com/deen-app/terms_and_conditions.html',
    );
    expect(
      AppConstants.supportUrl,
      'https://legal-sites.dgexpense.com/deen-app/support.html',
    );
    expect(
      AppConstants.deleteAccountUrl,
      'https://legal-sites.dgexpense.com/deen-app/delete_account.html',
    );
  });
}
