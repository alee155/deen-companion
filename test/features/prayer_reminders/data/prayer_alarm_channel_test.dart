import 'package:deen_companion/features/prayer_reminders/data/prayer_alarm_channel.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../_support/prayer_area_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.devsouq.deen_companion.app/prayer_alarms');
  final calls = <MethodCall>[];

  setUpAll(initFlavorForTests);
  tearDown(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  void handle(Future<Object?>? Function(MethodCall) h) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (c) async {
          calls.add(c);
          return h(c);
        });
  }

  group('PrayerAlarmEntry.toMap', () {
    test('uses epoch millis and carries snooze prefs', () {
      final at = DateTime.utc(2026, 9, 30, 12);
      final m = PrayerAlarmEntry(
        prayerName: 'dhuhr',
        triggerAt: at,
        label: 'Dhuhr',
        snoozeEnabled: false,
        snoozeMinutes: 15,
      ).toMap();
      expect(m['epochMillis'], at.millisecondsSinceEpoch);
      expect(m['reminderType'], 'atTime');
      expect(m['snoozeEnabled'], false);
      expect(m['snoozeMinutes'], 15);
      expect(m['prayerName'], 'dhuhr');
    });
  });

  group('PrayerAlarmChannel', () {
    const ch = PrayerAlarmChannel();
    final entry = PrayerAlarmEntry(
      prayerName: 'fajr',
      triggerAt: DateTime.utc(2026, 10, 1, 1),
      label: 'Fajr',
    );

    test('pushSchedule sends entries and returns the armed count', () async {
      handle((c) async => 1);
      final armed = await ch.pushSchedule([entry], snoozeMinutes: 7);
      expect(armed, 1);
      expect(calls.single.method, 'pushSchedule');
      final args = calls.single.arguments as Map;
      expect(args['snoozeMinutes'], 7);
      expect((args['entries'] as List).single['prayerName'], 'fajr');
    });

    test('missing plugin (iOS) degrades to null', () async {
      // no handler registered -> MissingPluginException
      expect(await ch.pushSchedule([entry]), isNull);
    });

    test('platform exception degrades to null instead of throwing', () async {
      handle((c) async => throw PlatformException(code: 'boom'));
      expect(await ch.pushSchedule([entry]), isNull);
    });

    test('cancelAll invokes cancelAllAlarms', () async {
      handle((c) async => null);
      await ch.cancelAll();
      expect(calls.single.method, 'cancelAllAlarms');
    });

    test('boolean getters: native answer is passed through', () async {
      handle((c) async => false);
      expect(await ch.notificationsEnabled(), isFalse);
      expect(await ch.canUseFullScreenIntent(), isFalse);
      expect(await ch.isIgnoringBatteryOptimizations(), isFalse);
    });

    test('boolean getters default sensibly when platform is missing', () async {
      // notifications default false; the "can I" checks default true so a
      // missing platform never nags the user.
      expect(await ch.notificationsEnabled(), isFalse);
      expect(await ch.canUseFullScreenIntent(), isTrue);
      expect(await ch.isIgnoringBatteryOptimizations(), isTrue);
    });

    test('settings openers call the matching native methods', () async {
      handle((c) async => null);
      await ch.openFullScreenIntentSettings();
      await ch.requestIgnoreBatteryOptimizations();
      expect(calls.map((c) => c.method), [
        'openFullScreenIntentSettings',
        'requestIgnoreBatteryOptimizations',
      ]);
    });
  });
}
