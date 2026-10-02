import 'package:deen_companion/core/error/exceptions.dart';
import 'package:deen_companion/core/location/location_service.dart';
import 'package:deen_companion/features/prayer_times/data/datasources/prayer_times_remote_datasource.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDio extends Mock implements Dio {}

Map<String, dynamic> _entry(String gdate, String fajr) => {
  'timings': {
    'Fajr': fajr,
    'Dhuhr': '12:00 (PKT)',
    'Asr': '15:00 (PKT)',
    'Maghrib': '18:00 (PKT)',
    'Isha': '19:00 (PKT)',
  },
  'date': {
    'gregorian': {'date': gdate},
    'hijri': {
      'day': '1',
      'month': {'en': 'Muharram'},
      'year': '1448',
    },
  },
};

void main() {
  late _MockDio dio;
  late PrayerTimesRemoteDataSourceImpl ds;
  const coords = Coordinates(latitude: 31.5, longitude: 74.3);

  setUp(() {
    dio = _MockDio();
    ds = PrayerTimesRemoteDataSourceImpl(dio);
  });

  Response<dynamic> ok(dynamic data) => Response(
    requestOptions: RequestOptions(path: ''),
    data: data,
    statusCode: 200,
  );

  group('getTimings', () {
    test('sends coordinates, method and school and parses the body', () async {
      when(
        () => dio.get(any(), queryParameters: any(named: 'queryParameters')),
      ).thenAnswer(
        (_) async => ok({'data': _entry('30-09-2026', '04:41 (PKT)')}),
      );

      final m = await ds.getTimings(coords, method: 1, school: 1);
      expect(m.fajr, DateTime(2026, 9, 30, 4, 41));

      final captured = verify(
        () => dio.get(
          captureAny(),
          queryParameters: captureAny(named: 'queryParameters'),
        ),
      ).captured;
      expect(captured[0], startsWith('https://api.aladhan.com/v1/timings/'));
      expect(captured[1], {
        'latitude': 31.5,
        'longitude': 74.3,
        'method': 1,
        'school': 1,
      });
    });

    test('DioException becomes ServerException with its message', () async {
      when(
        () => dio.get(any(), queryParameters: any(named: 'queryParameters')),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: ''),
          message: 'boom',
        ),
      );
      expect(
        () => ds.getTimings(coords, method: 3, school: 0),
        throwsA(
          isA<ServerException>().having((e) => e.message, 'message', 'boom'),
        ),
      );
    });

    test('non-map body surfaces a cast error (repository maps it)', () async {
      when(
        () => dio.get(any(), queryParameters: any(named: 'queryParameters')),
      ).thenAnswer((_) async => ok('<html>'));
      expect(
        () => ds.getTimings(coords, method: 3, school: 0),
        throwsA(isA<TypeError>()),
      );
    });
  });

  group('getMonthCalendar', () {
    test('requests year/month url and parses every day', () async {
      when(
        () => dio.get(any(), queryParameters: any(named: 'queryParameters')),
      ).thenAnswer(
        (_) async => ok({
          'data': [
            _entry('01-10-2026', '04:42 (PKT)'),
            _entry('02-10-2026', '04:43 (PKT)'),
          ],
        }),
      );

      final days = await ds.getMonthCalendar(
        coords,
        year: 2026,
        month: 10,
        method: 3,
        school: 0,
      );
      expect(days, hasLength(2));
      expect(days[1].fajr, DateTime(2026, 10, 2, 4, 43));
      verify(
        () => dio.get(
          'https://api.aladhan.com/v1/calendar/2026/10',
          queryParameters: any(named: 'queryParameters'),
        ),
      ).called(1);
    });

    test('empty data list yields an empty list', () async {
      when(
        () => dio.get(any(), queryParameters: any(named: 'queryParameters')),
      ).thenAnswer((_) async => ok({'data': <dynamic>[]}));
      expect(
        await ds.getMonthCalendar(
          coords,
          year: 2026,
          month: 2,
          method: 3,
          school: 0,
        ),
        isEmpty,
      );
    });

    test('DioException becomes ServerException', () async {
      when(
        () => dio.get(any(), queryParameters: any(named: 'queryParameters')),
      ).thenThrow(DioException(requestOptions: RequestOptions(path: '')));
      expect(
        () => ds.getMonthCalendar(
          coords,
          year: 2026,
          month: 2,
          method: 3,
          school: 0,
        ),
        throwsA(isA<ServerException>()),
      );
    });
  });
}
