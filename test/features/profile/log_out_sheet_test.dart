import 'package:deen_companion/features/profile/presentation/widgets/log_out_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _open(WidgetTester tester, void Function(bool?) onResult) async {
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, _) => MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => onResult(await showLogOutSheet(context)),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Log out confirms with true', (tester) async {
    bool? result;
    await _open(tester, (r) => result = r);
    expect(find.text('Log out?'), findsOneWidget);
    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
    expect(find.text('Log out?'), findsNothing);
  });

  testWidgets('Cancel closes without confirming', (tester) async {
    var done = false;
    bool? result;
    await _open(tester, (r) {
      done = true;
      result = r;
    });
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(done, isTrue);
    expect(result, isNull);
  });
}
