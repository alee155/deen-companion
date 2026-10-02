import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:deen_companion/features/qibla/domain/entities/qibla_info.dart';
import 'package:deen_companion/features/qibla/presentation/providers/qibla_providers.dart';
import 'package:deen_companion/features/qibla/presentation/screens/qibla_screen.dart';
import 'package:deen_companion/features/qibla/presentation/widgets/qibla_dial.dart';
import 'package:deen_companion/features/qibla/presentation/widgets/qibla_radar.dart';

class _FakeQibla extends QiblaNotifier {
  @override
  Future<QiblaInfo> build() async => const QiblaInfo(
    qiblaDirection: 258,
    compassBearing: 'WSW',
    distanceKm: 6123,
    distanceMiles: 3805,
    note: '',
    latitude: 31.5,
    longitude: 74.3,
  );
}

Widget _app(Stream<CompassReading> compass) => ProviderScope(
  overrides: [
    qiblaNotifierProvider.overrideWith(_FakeQibla.new),
    magneticDeclinationProvider.overrideWith((ref) async => 0.0),
    compassHeadingProvider.overrideWith((ref) => compass),
  ],
  child: ScreenUtilInit(
    designSize: const Size(390, 844),
    builder: (_, _) => const MaterialApp(home: QiblaScreen()),
  ),
);

void main() {
  testWidgets(
    'shows the radar until a compass reading arrives, then the dial',
    (tester) async {
      final controller = StreamController<CompassReading>();
      addTearDown(controller.close);

      await tester.pumpWidget(_app(controller.stream));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byType(QiblaRadar), findsOneWidget);

      controller.add(const CompassReading(heading: 100, accuracy: 10));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(seconds: 2));

      expect(find.byType(QiblaDial), findsOneWidget);
      expect(find.text('Turn 158° to the right'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('locks when the heading lines up with the Qibla', (tester) async {
    final controller = StreamController<CompassReading>();
    addTearDown(controller.close);

    await tester.pumpWidget(_app(controller.stream));
    controller.add(const CompassReading(heading: 256, accuracy: 10));
    // Several frames: data arrives, the aligned build schedules the lock in a
    // post-frame callback, then the locked UI animates in.
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 400));
    }

    expect(find.text('Locked onto the Qibla'), findsOneWidget);
    expect(find.text('Recheck'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('falls back to the static bearing when no compass reports', (
    tester,
  ) async {
    final controller = StreamController<CompassReading>();
    addTearDown(controller.close);

    await tester.pumpWidget(_app(controller.stream));
    controller.add(const CompassReading(heading: null, accuracy: null));
    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(seconds: 2));

    expect(find.text('Face the bearing below'), findsOneWidget);
    expect(find.textContaining("couldn't get a reading"), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
