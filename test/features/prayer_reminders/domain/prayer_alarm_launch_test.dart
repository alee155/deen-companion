import 'package:deen_companion/features/prayer_reminders/domain/prayer_alarm_launch.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reads what the iOS alarm hand-off sends', () {
    final launch = PrayerAlarmLaunch.fromMap({
      'prayerName': 'fajr',
      'label': 'Fajr — time to pray',
      'epochMillis': 1700000000000.0, // Swift sends a Double
      'snoozeMinutes': 10,
    })!;

    expect(launch.prayerName, 'fajr');
    expect(launch.displayName, 'Fajr');
    expect(launch.label, 'Fajr — time to pray');
    expect(launch.time, DateTime.fromMillisecondsSinceEpoch(1700000000000));
    expect(launch.snoozeMinutes, 10);
    expect(launch.canSnooze, isTrue);
  });

  test('snooze minutes of 0 mean the prayer has snooze switched off', () {
    final launch = PrayerAlarmLaunch.fromMap({
      'prayerName': 'asr',
      'epochMillis': 1,
      'snoozeMinutes': 0,
    })!;
    expect(launch.canSnooze, isFalse);
  });

  test('falls back to the prayer id for the label', () {
    final launch = PrayerAlarmLaunch.fromMap({
      'prayerName': 'isha',
      'epochMillis': 1,
    })!;
    expect(launch.label, 'isha');
    expect(launch.snoozeMinutes, 0);
  });

  test('unusable payloads are ignored, not thrown on', () {
    expect(PrayerAlarmLaunch.fromMap({'epochMillis': 1}), isNull);
    expect(PrayerAlarmLaunch.fromMap({'prayerName': 'fajr'}), isNull);
    expect(PrayerAlarmLaunch.fromMap({}), isNull);
  });
}
