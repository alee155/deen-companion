import 'package:deen_companion/features/prayer_logs/presentation/widgets/snap_photo_viewer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host() => ScreenUtilInit(
  designSize: const Size(390, 844),
  builder: (_, _) => MaterialApp(
    home: Builder(
      builder: (context) => Scaffold(
        body: TextButton(
          onPressed: () => showSnapPhoto(
            context,
            url: 'http://localhost/none.jpg',
            title: 'Ali',
            subtitle: 'Dhuhr · 2m ago',
          ),
          child: const Text('open'),
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('opens full screen with sender, prayer and a progress bar', (
    tester,
  ) async {
    await tester.pumpWidget(_host());
    await tester.tap(find.text('open'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Ali'), findsOneWidget);
    expect(find.text('Dhuhr · 2m ago'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('tapping the photo closes it', (tester) async {
    await tester.pumpWidget(_host());
    await tester.tap(find.text('open'));
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byType(SnapPhoto));
    await tester.pumpAndSettle();

    expect(find.text('Ali'), findsNothing);
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('closes by itself when the bar is full', (tester) async {
    await tester.pumpWidget(_host());
    await tester.tap(find.text('open'));
    await tester.pump(const Duration(milliseconds: 300));

    await tester.pump(const Duration(seconds: 7));
    await tester.pumpAndSettle();

    expect(find.text('Ali'), findsNothing);
  });

  testWidgets('swiping down closes it', (tester) async {
    await tester.pumpWidget(_host());
    await tester.tap(find.text('open'));
    await tester.pump(const Duration(milliseconds: 300));

    await tester.fling(find.byType(SnapPhoto), const Offset(0, 400), 1500);
    await tester.pumpAndSettle();

    expect(find.text('Ali'), findsNothing);
  });
}
