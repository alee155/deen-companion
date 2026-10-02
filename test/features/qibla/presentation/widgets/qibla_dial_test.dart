import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:deen_companion/features/qibla/presentation/widgets/qibla_dial.dart';
import 'package:deen_companion/features/qibla/presentation/widgets/qibla_info_widgets.dart';

Widget _wrap(Widget child) => ScreenUtilInit(
  designSize: const Size(390, 844),
  builder: (_, _) => MaterialApp(
    home: Scaffold(body: Center(child: child)),
  ),
);

void main() {
  testWidgets('dial renders, rotates across north without throwing', (
    tester,
  ) async {
    Widget dial(double heading) => _wrap(
      QiblaDial(
        heading: heading,
        qiblaDirection: 258,
        aligned: false,
        size: 300,
      ),
    );

    await tester.pumpWidget(dial(350));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpWidget(dial(5));
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(QiblaDial), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('status card shows turn guidance, then the aligned state', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        QiblaStatusCard(
          diff: 24,
          aligned: false,
          locked: false,
          onRecheck: () {},
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Turn 24° to the right'), findsOneWidget);

    await tester.pumpWidget(
      _wrap(
        QiblaStatusCard(
          diff: 2,
          aligned: true,
          locked: false,
          onRecheck: () {},
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(find.text("You're facing the Qibla"), findsOneWidget);
  });

  testWidgets('locked card exposes a working Recheck button', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      _wrap(
        QiblaStatusCard(
          diff: 0,
          aligned: true,
          locked: true,
          onRecheck: () => taps++,
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('Recheck'));
    expect(taps, 1);
  });
}
