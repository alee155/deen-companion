import 'package:deen_companion/features/prayer_logs/data/prayer_log_models.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _log({Object? view}) => {
  'id': 'l1',
  'prayer': 'dhuhr',
  'date': '2026-10-20',
  'status': 'on_time',
  'points': 5,
  'snapUrl': 'https://x.test/a.jpg',
  'windowStartsAt': '2026-10-20T08:00:00.000Z',
  'windowEndsAt': '2026-10-20T11:00:00.000Z',
  'loggedAt': '2026-10-20T09:00:00.000Z',
  'viewDurationSeconds': ?view,
};

void main() {
  test('a log carries the sender\'s view duration', () {
    final l = prayerLogFromJson(_log(view: 7));
    expect(l.viewDurationSeconds, 7);
    expect(l.viewDuration(), const Duration(seconds: 7));
  });

  test('without it the viewer falls back to the default', () {
    final l = prayerLogFromJson(_log());
    expect(l.viewDurationSeconds, isNull);
    expect(l.viewDuration(), const Duration(seconds: 6));
  });
}
