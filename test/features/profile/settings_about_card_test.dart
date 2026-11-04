import 'package:deen_companion/features/profile/presentation/widgets/settings_about_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('About lists the four legal pages and each opens its own link', (
    tester,
  ) async {
    final opened = <String>[];
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, _) => MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SettingsAboutCard(
                version: '1.0.0',
                onPrivacy: () => opened.add('privacy'),
                onTerms: () => opened.add('terms'),
                onSupport: () => opened.add('support'),
                onDeleteAccount: () => opened.add('delete'),
              ),
            ),
          ),
        ),
      ),
    );

    for (final title in [
      'Privacy Policy',
      'Terms & Conditions',
      'Support',
      'Delete Account',
    ]) {
      await tester.tap(find.text(title));
    }
    expect(opened, ['privacy', 'terms', 'support', 'delete']);
    expect(find.text('1.0.0'), findsOneWidget);
  });
}
