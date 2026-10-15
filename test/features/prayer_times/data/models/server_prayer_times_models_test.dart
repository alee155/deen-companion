import 'package:deen_companion/features/prayer_times/data/models/server_prayer_times_models.dart';
import 'package:deen_companion/features/prayer_times/domain/entities/prayer_times.dart';
import 'package:flutter_test/flutter_test.dart';

/// Shaped exactly like the backend's documented response (Lahore, Karachi
/// method, Hanafi Asr, 14 and 15 Oct 2026).
Map<String, dynamic> _response({bool withLocked = false}) => {
  'location': {
    'latitude': 31.52,
    'longitude': 74.36,
    'timezone': 'Asia/Karachi',
  },
  'method': {
    'id': 1,
    'name': 'University of Islamic Sciences, Karachi',
    'school': 'hanafi',
    'schoolId': 1,
  },
  'days': [
    {
      'date': '2026-10-14',
      'fajr': '2026-10-13T23:44:00.000Z',
      'sunrise': '2026-10-14T01:05:00.000Z',
      'dhuhr': '2026-10-14T06:49:00.000Z',
      'asr': '2026-10-14T10:54:00.000Z',
      'maghrib': '2026-10-14T12:32:00.000Z',
      'isha': '2026-10-14T13:53:00.000Z',
      'local': {
        'fajr': '2026-10-14T04:44:00+05:00',
        'sunrise': '2026-10-14T06:05:00+05:00',
        'dhuhr': '2026-10-14T11:49:00+05:00',
        'asr': '2026-10-14T15:54:00+05:00',
        'maghrib': '2026-10-14T17:32:00+05:00',
        'isha': '2026-10-14T18:53:00+05:00',
      },
      'hijri': {
        'day': 3,
        'month': 5,
        'year': 1448,
        'monthName': 'Jumādá al-ūlá',
        'monthNameAr': 'جُمادى الأولى',
      },
    },
    {
      'date': '2026-10-15',
      'fajr': '2026-10-14T23:45:00.000Z',
      'sunrise': '2026-10-15T01:06:00.000Z',
      'dhuhr': '2026-10-15T06:49:00.000Z',
      'asr': '2026-10-15T10:53:00.000Z',
      'maghrib': '2026-10-15T12:31:00.000Z',
      'isha': '2026-10-15T13:52:00.000Z',
      'local': {
        'fajr': '2026-10-15T04:45:00+05:00',
        'sunrise': '2026-10-15T06:06:00+05:00',
        'dhuhr': '2026-10-15T11:49:00+05:00',
        'asr': '2026-10-15T15:53:00+05:00',
        'maghrib': '2026-10-15T17:31:00+05:00',
        'isha': '2026-10-15T18:52:00+05:00',
      },
      'hijri': null,
    },
  ],
  if (withLocked) 'lockedDates': ['2026-10-14'],
};

void main() {
  group('bundle', () {
    final bundle = PrayerTimesBundleModel.fromJson(_response()).toEntity();

    test('location and method', () {
      expect(bundle.location.timezone, 'Asia/Karachi');
      expect(bundle.location.latitude, 31.52);
      expect(bundle.method.id, 1);
      expect(bundle.method.schoolId, 1);
      expect(
        bundle.method.sourceLabel,
        'Calculated: University of Islamic Sciences, Karachi, Hanafi Asr',
      );
    });

    test('days keep their server date', () {
      expect(bundle.days.map((d) => d.date), ['2026-10-14', '2026-10-15']);
    });

    test('times are the UTC instants', () {
      final t = bundle.days.first.times;
      expect(t.fajr.toUtc(), DateTime.utc(2026, 10, 13, 23, 44));
      expect(t.sunrise!.toUtc(), DateTime.utc(2026, 10, 14, 1, 5));
      expect(t.isha.toUtc(), DateTime.utc(2026, 10, 14, 13, 53));
    });

    test('the clock face comes from the offset in the local text', () {
      final t = bundle.days.first.times;
      expect(t.utcOffset, const Duration(hours: 5));
      final f = t.wallClock(t.fajr);
      expect((f.hour, f.minute), (4, 44));
      final i = t.wallClock(t.isha);
      expect((i.hour, i.minute), (18, 53));
    });

    test('each day points at the next day\'s Fajr', () {
      expect(
        bundle.days.first.times.nextFajr!.toUtc(),
        DateTime.utc(2026, 10, 14, 23, 45),
      );
      expect(bundle.days.last.times.nextFajr, isNull);
    });

    test('Hijri label, and nothing when the provider sent none', () {
      expect(bundle.days.first.times.hijriDate, '3 Jumādá al-ūlá 1448 AH');
      expect(bundle.days.last.times.hijriDate, isEmpty);
    });

    test('lockedDates default to none and are read when present', () {
      expect(bundle.lockedDates, isEmpty);
      final locked = PrayerTimesBundleModel.fromJson(
        _response(withLocked: true),
      ).toEntity();
      expect(locked.lockedDates, ['2026-10-14']);
    });
  });

  test(
    'toJson returns exactly the response, so a cached copy parses the same',
    () {
      final raw = _response(withLocked: true);
      final model = PrayerTimesBundleModel.fromJson(raw);
      expect(model.toJson(), raw);
      expect(
        PrayerTimesBundleModel.fromJson(model.toJson()).toEntity(),
        model.toEntity(),
      );
    },
  );

  group('offsetOf', () {
    test('parses signs, half hours and Z', () {
      expect(offsetOf('2026-10-14T04:44:00+05:00'), const Duration(hours: 5));
      expect(
        offsetOf('2026-10-14T04:44:00-03:30'),
        const Duration(hours: -3, minutes: -30),
      );
      expect(
        offsetOf('2026-10-14T04:44:00+0530'),
        const Duration(hours: 5, minutes: 30),
      );
      expect(offsetOf('2026-10-14T04:44:00Z'), Duration.zero);
    });

    test('is null when there is no offset', () {
      expect(offsetOf('2026-10-14T04:44:00'), isNull);
      expect(offsetOf(null), isNull);
    });
  });

  test('a phone in another timezone still shows the prayer place\'s clock', () {
    // The same bundle read by a phone anywhere gives the same wall clock,
    // because it is derived from the UTC instant plus the location's offset.
    final t = PrayerTimesBundleModel.fromJson(
      _response(),
    ).toEntity().days.first.times;
    final shown = t.wallClock(t.dhuhr);
    expect((shown.hour, shown.minute), (11, 49));
    expect(PrayerName.values, hasLength(5));
  });

  group('small parsers', () {
    test('city', () {
      final c = prayerCityFromJson({
        'name': 'Lahore',
        'region': 'Punjab',
        'country': 'Pakistan',
        'countryCode': 'PK',
        'latitude': 31.558,
        'longitude': 74.3507,
        'timezone': 'Asia/Karachi',
      });
      expect(c.label, 'Lahore, Punjab, Pakistan');
      expect(c.countryCode, 'PK');
    });

    test('a city whose region repeats its name is not repeated', () {
      final c = prayerCityFromJson({
        'name': 'Singapore',
        'region': 'Singapore',
        'country': 'Singapore',
        'countryCode': 'SG',
        'latitude': 1.29,
        'longitude': 103.85,
        'timezone': 'Asia/Singapore',
      });
      expect(c.label, 'Singapore, Singapore');
    });

    test('saved settings before the first PUT are empty', () {
      final s = savedSettingsFromJson({'location': null, 'method': null});
      expect(s.location, isNull);
      expect(s.method, isNull);
    });

    test('saved settings after a PUT', () {
      final s = savedSettingsFromJson({
        'location': {
          'latitude': 31.52,
          'longitude': 74.36,
          'timezone': 'Asia/Karachi',
        },
        'method': {
          'id': 1,
          'name': 'Karachi',
          'school': 'hanafi',
          'schoolId': 1,
        },
        'defaults': {'method': 1, 'school': 1},
      });
      expect(s.location!.timezone, 'Asia/Karachi');
      expect(s.method!.schoolId, 1);
    });
  });
}
