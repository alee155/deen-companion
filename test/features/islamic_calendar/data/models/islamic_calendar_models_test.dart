import 'package:deen_companion/features/islamic_calendar/data/models/hijri_conversion_model.dart';
import 'package:deen_companion/features/islamic_calendar/data/models/islamic_events_bundle_model.dart';
import 'package:deen_companion/features/islamic_calendar/data/models/islamic_month_model.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../_fixtures.dart';

void main() {
  group('HijriConversionModel', () {
    test('parses gregorian, hijri and the nested islamic_info note', () {
      final m = HijriConversionModel.fromJson(conversionJson());
      expect(m.gregorian.day, 16);
      expect(m.gregorian.month, 6);
      expect(m.gregorian.year, 2026);
      expect(m.hijri.day, 1);
      expect(m.hijri.month, 1);
      expect(m.hijri.year, 1448);
      expect(m.hijri.monthName, 'Muharram');
      expect(m.hijri.era, 'AH');
      expect(m.note, 'Calculated date');
    });

    test('islamic_info absent -> note null', () {
      final m = HijriConversionModel.fromJson(conversionJson(note: null));
      expect(m.note, isNull);
    });

    test('optional day_of_week and era may be missing', () {
      final g = gregorianJson()..remove('day_of_week');
      final h = hijriJson()..remove('era');
      final m = HijriConversionModel.fromJson({'gregorian': g, 'hijri': h});
      expect(m.gregorian.dayOfWeek, isNull);
      expect(m.hijri.era, isNull);
    });

    test('missing hijri block throws', () {
      expect(
        () => HijriConversionModel.fromJson({'gregorian': gregorianJson()}),
        throwsA(isA<TypeError>()),
      );
    });

    test('day as a string (API drift) throws instead of silently parsing', () {
      final h = hijriJson()..['day'] = '1';
      expect(
        () => HijriConversionModel.fromJson({
          'gregorian': gregorianJson(),
          'hijri': h,
        }),
        throwsA(isA<TypeError>()),
      );
    });

    test('toJson/fromJson round trip keeps every field and the note', () {
      final m = HijriConversionModel.fromJson(conversionJson());
      final back = HijriConversionModel.fromJson(m.toJson());
      expect(back.toJson(), m.toJson());
      expect(back.note, 'Calculated date');
    });

    test('toJson omits islamic_info when there is no note', () {
      final m = HijriConversionModel.fromJson(conversionJson(note: null));
      expect(m.toJson().containsKey('islamic_info'), isFalse);
    });

    test('toEntity preserves all values', () {
      final e = HijriConversionModel.fromJson(conversionJson()).toEntity();
      expect(e.gregorian.formatted, 'Tuesday, June 16, 2026');
      expect(e.hijri.monthNameArabic, 'محرم');
      expect(e.hijri.year, 1448);
      expect(e.note, 'Calculated date');
    });

    test('last day of a 30-day month and first day of next round-trip', () {
      final h = hijriJson(day: 30, month: 12, year: 1447);
      final m = HijriConversionModel.fromJson({
        'gregorian': gregorianJson(),
        'hijri': h,
      });
      expect(m.hijri.day, 30);
      expect(m.hijri.month, 12);
      expect(m.hijri.year, 1447);
    });
  });

  group('IslamicEventsBundleModel', () {
    test('parses current date, next event and the events list', () {
      final b = IslamicEventsBundleModel.fromJson(eventsBundleJson());
      expect(b.currentDate.hijri.year, 1448);
      expect(b.nextEvent.name, 'Ashura');
      expect(b.nextEvent.hijriDateFormatted, '10 Muharram 1448');
      expect(b.events.map((e) => e.name), ['Islamic New Year', 'Ramadan begins']);
      expect(b.events[1].month, 9);
    });

    test('empty events list is allowed', () {
      final j = eventsBundleJson()..['events'] = <dynamic>[];
      expect(IslamicEventsBundleModel.fromJson(j).events, isEmpty);
    });

    test('missing next_event throws', () {
      final j = eventsBundleJson()..remove('next_event');
      expect(() => IslamicEventsBundleModel.fromJson(j), throwsA(isA<TypeError>()));
    });

    test('event missing description throws', () {
      final j = eventsBundleJson();
      ((j['events'] as List).first as Map).remove('description');
      expect(() => IslamicEventsBundleModel.fromJson(j), throwsA(isA<TypeError>()));
    });

    test('toJson round trip is lossless', () {
      final b = IslamicEventsBundleModel.fromJson(eventsBundleJson());
      expect(
        IslamicEventsBundleModel.fromJson(b.toJson()).toJson(),
        b.toJson(),
      );
    });

    test('event / next-event toEntity', () {
      final b = IslamicEventsBundleModel.fromJson(eventsBundleJson());
      expect(b.events.first.toEntity().description, 'd1');
      final n = b.nextEvent.toEntity();
      expect((n.month, n.day), (1, 10));
    });
  });

  group('IslamicMonthModel', () {
    test('parse, round trip, entity', () {
      final m = IslamicMonthModel.fromJson(monthJson(9));
      expect(m.number, 9);
      expect(IslamicMonthModel.fromJson(m.toJson()).toJson(), m.toJson());
      expect(m.toEntity().nameEnglish, 'Month9');
    });

    test('missing significance throws', () {
      final j = monthJson(1)..remove('significance');
      expect(() => IslamicMonthModel.fromJson(j), throwsA(isA<TypeError>()));
    });
  });
}
