import 'package:deen_companion/features/points/domain/entities/points_rule.dart';
import 'package:deen_companion/features/prayer_times/domain/entities/prayer_times.dart';
import 'package:flutter_test/flutter_test.dart';

PointsRule _r(String prayer, int points) =>
    PointsRule(prayer: prayer, points: points);

void main() {
  group('PointsRule', () {
    test('knows the prayers of this app', () {
      expect(_r('fajr', 10).prayerName, PrayerName.fajr);
      expect(_r('isha', 5).prayerName, PrayerName.isha);
    });

    test('a prayer it does not know is kept, not dropped', () {
      expect(_r('jumuah', 8).prayerName, isNull);
      expect(_r('jumuah', 8).prayer, 'jumuah');
    });
  });

  group('PointsRules', () {
    test('lists Fajr to Isha whatever order the server used', () {
      final t = PointsRules([
        _r('isha', 5),
        _r('fajr', 10),
        _r('asr', 5),
        _r('dhuhr', 5),
        _r('maghrib', 5),
      ]);
      expect(t.rules.map((r) => r.prayer), [
        'fajr',
        'dhuhr',
        'asr',
        'maghrib',
        'isha',
      ]);
    });

    test('unknown prayers come after, in the order the server sent them', () {
      final t = PointsRules([
        _r('jumuah', 8),
        _r('asr', 5),
        _r('tahajjud', 3),
        _r('fajr', 10),
      ]);
      expect(t.rules.map((r) => r.prayer), [
        'fajr',
        'asr',
        'jumuah',
        'tahajjud',
      ]);
    });

    test('highest is the best any prayer earns', () {
      expect(PointsRules([_r('fajr', 10), _r('asr', 5)]).highest, 10);
      expect(PointsRules(const []).highest, 0);
    });

    test('total is what a full day earns', () {
      expect(
        PointsRules([
          _r('fajr', 10),
          _r('dhuhr', 5),
          _r('asr', 5),
          _r('maghrib', 5),
          _r('isha', 5),
        ]).total,
        30,
      );
      expect(PointsRules(const []).total, 0);
    });

    test('isEmpty', () {
      expect(PointsRules(const []).isEmpty, isTrue);
      expect(PointsRules([_r('fajr', 1)]).isEmpty, isFalse);
    });

    test(
      'equal tables are equal (so the cache-first notifier can compare)',
      () {
        expect(
          PointsRules([_r('fajr', 10), _r('asr', 5)]),
          PointsRules([_r('asr', 5), _r('fajr', 10)]),
        );
        expect(
          PointsRules([_r('fajr', 10)]),
          isNot(PointsRules([_r('fajr', 9)])),
        );
      },
    );
  });
}
