import 'package:deen_companion/features/prayer_dnd/data/prayer_dnd_channel.dart';
import 'package:deen_companion/features/prayer_dnd/domain/dnd_window.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../_support/prayer_area_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const mc = MethodChannel('com.devsouq.deen_companion.app/prayer_dnd');
  const ch = PrayerDndChannel();
  final calls = <MethodCall>[];

  setUpAll(initFlavorForTests);
  tearDown(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(mc, null);
  });

  void handle(Future<Object?> Function(MethodCall) h) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(mc, (c) {
          calls.add(c);
          return h(c);
        });
  }

  final windows = [
    DndWindow(
      prayerName: 'fajr',
      start: DateTime.utc(2026, 10, 1, 5),
      end: DateTime.utc(2026, 10, 1, 5, 15),
    ),
  ];

  test('pushSchedule serialises windows and returns armed count', () async {
    handle((_) async => 1);
    expect(await ch.pushSchedule(windows), 1);
    final entries = (calls.single.arguments as Map)['entries'] as List;
    expect(entries.single['prayerName'], 'fajr');
    expect(
      entries.single['endMillis'] - entries.single['startMillis'],
      15 * 60 * 1000,
    );
  });

  test('missing platform and platform errors degrade to null', () async {
    expect(await ch.pushSchedule(windows), isNull);
    handle((_) async => throw PlatformException(code: 'x'));
    expect(await ch.pushSchedule(windows), isNull);
  });

  test(
    'hasPolicyAccess defaults to false, canScheduleExactAlarms to true',
    () async {
      expect(await ch.hasPolicyAccess(), isFalse);
      expect(await ch.canScheduleExactAlarms(), isTrue);
    },
  );

  test('answers from native are passed through', () async {
    handle((_) async => true);
    expect(await ch.hasPolicyAccess(), isTrue);
    handle((_) async => false);
    expect(await ch.canScheduleExactAlarms(), isFalse);
  });

  test('cancelAll and settings openers hit the right methods', () async {
    handle((_) async => null);
    await ch.cancelAll();
    await ch.openPolicyAccessSettings();
    await ch.openExactAlarmSettings();
    expect(calls.map((c) => c.method), [
      'cancelAll',
      'openPolicyAccessSettings',
      'openExactAlarmSettings',
    ]);
  });
}
