import 'package:deen_companion/core/device/platform_support.dart';
import 'package:deen_companion/features/profile/presentation/widgets/prayer_silence_guide_tile.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ScreenUtilInit(
      designSize: const Size(375, 812),
      builder: (_, _) => const MaterialApp(
        home: Scaffold(body: Center(child: PrayerSilenceGuideTile())),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('PlatformSupport', () {
    tearDown(() => debugDefaultTargetPlatformOverride = null);

    test('Android gets the real Do Not Disturb, not the guide', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      expect(PlatformSupport.prayerDnd, isTrue);
      expect(PlatformSupport.prayerSilenceGuide, isFalse);
    });

    test('iOS gets the guide, not Do Not Disturb', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      expect(PlatformSupport.prayerDnd, isFalse);
      expect(PlatformSupport.prayerSilenceGuide, isTrue);
    });
  });

  group('PrayerSilenceGuideTile', () {
    testWidgets('says plainly it is a set-up guide, not a switch', (
      tester,
    ) async {
      await _pump(tester);

      expect(find.text('Silence your phone during prayer'), findsOneWidget);
      expect(find.textContaining('Set it up in a minute'), findsOneWidget);
      expect(find.byType(Switch), findsNothing);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('opens the guide, with the three ways and the alarm note', (
      tester,
    ) async {
      await _pump(tester);

      await tester.tap(find.byType(PrayerSilenceGuideTile));
      await tester.pumpAndSettle(); // the sheet slides up

      expect(find.text('Create a Focus'), findsOneWidget);
      expect(find.text('Schedule it'), findsOneWidget);
      expect(find.text('Or use Shortcuts'), findsOneWidget);
      expect(
        find.textContaining('alarm still rings during any Focus'),
        findsOneWidget,
      );

      await tester.ensureVisible(find.text('Got it'));
      await tester.tap(find.text('Got it'));
      await tester.pumpAndSettle();
      expect(find.text('Create a Focus'), findsNothing);

      await tester.pumpWidget(const SizedBox());
    });
  });
}
