import 'dart:convert';

import 'package:deen_companion/features/prayer_reminders/domain/prayer_reminder_prefs.dart';
import 'package:deen_companion/features/prayer_times/domain/entities/prayer_times.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PrayerReminderPrefs', () {
    test('defaults: enabled, snooze on, 10 minutes', () {
      const p = PrayerReminderPrefs();
      expect(p.enabled, isTrue);
      expect(p.snoozeEnabled, isTrue);
      expect(p.snoozeMinutes, 10);
      expect(PrayerReminderPrefs.defaults, p);
    });

    test(
      'snooze options stay short enough not to run into the next prayer',
      () {
        expect(PrayerReminderPrefs.snoozeOptions, [5, 10, 15, 20]);
      },
    );

    test('copyWith overrides individually', () {
      const p = PrayerReminderPrefs();
      expect(p.copyWith(enabled: false).enabled, isFalse);
      expect(p.copyWith(enabled: false).snoozeMinutes, 10);
      expect(p.copyWith(snoozeMinutes: 20).snoozeMinutes, 20);
      expect(p.copyWith(snoozeEnabled: false).snoozeEnabled, isFalse);
    });

    test('equality and hashCode follow values', () {
      expect(
        const PrayerReminderPrefs(snoozeMinutes: 5),
        const PrayerReminderPrefs(snoozeMinutes: 5),
      );
      expect(
        const PrayerReminderPrefs(snoozeMinutes: 5).hashCode,
        const PrayerReminderPrefs(snoozeMinutes: 5).hashCode,
      );
      expect(
        const PrayerReminderPrefs(snoozeMinutes: 5) ==
            const PrayerReminderPrefs(snoozeMinutes: 15),
        isFalse,
      );
    });

    test('fromJson fills missing/null fields with defaults', () {
      final p = PrayerReminderPrefs.fromJson({'enabled': false});
      expect(p.enabled, isFalse);
      expect(p.snoozeEnabled, isTrue);
      expect(p.snoozeMinutes, 10);
      final q = PrayerReminderPrefs.fromJson({
        'enabled': null,
        'snoozeMinutes': null,
      });
      expect(q, PrayerReminderPrefs.defaults);
    });

    test('fromJson with a wrongly typed field throws', () {
      expect(
        () => PrayerReminderPrefs.fromJson({'snoozeMinutes': '10'}),
        throwsA(isA<TypeError>()),
      );
    });

    test('toJson/fromJson round-trip', () {
      const p = PrayerReminderPrefs(
        enabled: false,
        snoozeEnabled: false,
        snoozeMinutes: 15,
      );
      expect(PrayerReminderPrefs.fromJson(p.toJson()), p);
    });
  });

  group('encode/decodePrayerPrefs', () {
    test('defaultPrayerPrefs covers all five prayers', () {
      expect(defaultPrayerPrefs().keys, PrayerName.values);
    });

    test('round trip preserves per-prayer values', () {
      final prefs = defaultPrayerPrefs()
        ..[PrayerName.fajr] = const PrayerReminderPrefs(
          snoozeEnabled: false,
          snoozeMinutes: 5,
        )
        ..[PrayerName.isha] = const PrayerReminderPrefs(enabled: false);
      final back = decodePrayerPrefs(encodePrayerPrefs(prefs));
      expect(back, prefs);
    });

    test('null input returns defaults', () {
      expect(decodePrayerPrefs(null), defaultPrayerPrefs());
    });

    test('corrupt JSON returns defaults rather than throwing', () {
      expect(decodePrayerPrefs('{not json'), defaultPrayerPrefs());
      expect(decodePrayerPrefs('[1,2]'), defaultPrayerPrefs());
      expect(decodePrayerPrefs(''), defaultPrayerPrefs());
    });

    test('missing prayers keep defaults, present ones are applied', () {
      final raw = jsonEncode({
        'asr': {'enabled': false},
        'bogus': {'enabled': false},
      });
      final decoded = decodePrayerPrefs(raw);
      expect(decoded[PrayerName.asr]!.enabled, isFalse);
      expect(decoded[PrayerName.fajr], PrayerReminderPrefs.defaults);
      expect(decoded.length, 5);
    });

    test('non-map entry for a prayer is ignored', () {
      final decoded = decodePrayerPrefs(jsonEncode({'fajr': 'off'}));
      expect(decoded[PrayerName.fajr], PrayerReminderPrefs.defaults);
    });

    test('entry with a bad field type stops decoding but never throws', () {
      // Entries before the bad one are kept; the bad one and later ones default.
      final raw = jsonEncode({
        'fajr': {'enabled': false},
        'dhuhr': {'snoozeMinutes': 'x'},
      });
      final decoded = decodePrayerPrefs(raw);
      expect(decoded[PrayerName.dhuhr], PrayerReminderPrefs.defaults);
    });

    test('encoded keys are prayer enum names', () {
      final json = jsonDecode(encodePrayerPrefs(defaultPrayerPrefs())) as Map;
      expect(json.keys, ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha']);
    });
  });
}
