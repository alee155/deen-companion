import 'package:deen_companion/features/prayer_times/data/models/prayer_times_model.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _api({
  Map<String, String>? timings,
  String date = '30-09-2026',
}) => {
  'data': {
    'timings':
        timings ??
        {
          'Fajr': '04:41 (PKT)',
          'Dhuhr': '12:05 (PKT)',
          'Asr': '15:30 (PKT)',
          'Maghrib': '18:02 (PKT)',
          'Isha': '19:20 (PKT)',
        },
    'date': {
      'gregorian': {'date': date},
      'hijri': {
        'day': '18',
        'month': {'en': 'Rabiʻ al-awwal'},
        'year': '1448',
      },
    },
  },
};

void main() {
  group('PrayerTimesModel.fromApiJson', () {
    test('parses timings on the DD-MM-YYYY gregorian date', () {
      final m = PrayerTimesModel.fromApiJson(_api());
      expect(m.fajr, DateTime(2026, 9, 30, 4, 41));
      expect(m.dhuhr, DateTime(2026, 9, 30, 12, 5));
      expect(m.asr, DateTime(2026, 9, 30, 15, 30));
      expect(m.maghrib, DateTime(2026, 9, 30, 18, 2));
      expect(m.isha, DateTime(2026, 9, 30, 19, 20));
    });

    test('strips the timezone suffix; accepts bare HH:mm too', () {
      final m = PrayerTimesModel.fromApiJson(
        _api(
          timings: {
            'Fajr': '05:00',
            'Dhuhr': '12:00 (+03)',
            'Asr': '15:00 (EST)',
            'Maghrib': '18:00',
            'Isha': '19:00',
          },
        ),
      );
      expect(m.fajr.hour, 5);
      expect(m.dhuhr.hour, 12);
      expect(m.asr.hour, 15);
    });

    test('builds the hijri label from day, english month and year', () {
      final m = PrayerTimesModel.fromApiJson(_api());
      expect(m.hijriDate, '18 Rabiʻ al-awwal 1448 AH');
    });

    test('day/month rollover at year end is preserved', () {
      final m = PrayerTimesModel.fromApiJson(_api(date: '31-12-2026'));
      expect(m.isha, DateTime(2026, 12, 31, 19, 20));
    });

    test('leap day parses', () {
      final m = PrayerTimesModel.fromApiJson(_api(date: '29-02-2028'));
      expect(m.fajr.day, 29);
      expect(m.fajr.month, 2);
    });

    test('polar-night placeholder time ("-----") throws FormatException', () {
      expect(
        () => PrayerTimesModel.fromApiJson(
          _api(
            timings: {
              'Fajr': '-----',
              'Dhuhr': '12:00',
              'Asr': '15:00',
              'Maghrib': '18:00',
              'Isha': '19:00',
            },
          ),
        ),
        throwsFormatException,
      );
    });

    test('missing prayer key throws', () {
      expect(
        () => PrayerTimesModel.fromApiJson(_api(timings: {'Fajr': '05:00'})),
        throwsA(isA<TypeError>()),
      );
    });

    test('missing data envelope throws', () {
      expect(
        () => PrayerTimesModel.fromApiJson(<String, dynamic>{}),
        throwsA(anything),
      );
    });

    test('malformed gregorian date throws', () {
      expect(
        () => PrayerTimesModel.fromApiJson(_api(date: '2026/09/30')),
        throwsFormatException,
      );
    });
  });

  group('PrayerTimesModel cache serialisation', () {
    final model = PrayerTimesModel(
      fajr: DateTime(2026, 9, 30, 4, 41),
      dhuhr: DateTime(2026, 9, 30, 12, 5),
      asr: DateTime(2026, 9, 30, 15, 30),
      maghrib: DateTime(2026, 9, 30, 18, 2),
      isha: DateTime(2026, 9, 30, 19, 20),
      hijriDate: '18 Rabi 1448 AH',
    );

    test('toJson/fromJson round-trips exactly', () {
      final back = PrayerTimesModel.fromJson(model.toJson());
      expect(back.toEntity(), model.toEntity());
    });

    test('toJson uses flat ISO strings and snake_case hijri key', () {
      final j = model.toJson();
      expect(j['fajr'], '2026-09-30T04:41:00.000');
      expect(j['hijri_date'], '18 Rabi 1448 AH');
    });

    test('fromJson with a missing field throws', () {
      final j = model.toJson()..remove('isha');
      expect(() => PrayerTimesModel.fromJson(j), throwsA(isA<TypeError>()));
    });

    test('fromJson rejects a non-ISO timestamp', () {
      final j = model.toJson()..['fajr'] = 'yesterday';
      expect(() => PrayerTimesModel.fromJson(j), throwsFormatException);
    });

    test('toEntity carries every field', () {
      final e = model.toEntity();
      expect(e.fajr, model.fajr);
      expect(e.isha, model.isha);
      expect(e.hijriDate, model.hijriDate);
    });
  });
}
