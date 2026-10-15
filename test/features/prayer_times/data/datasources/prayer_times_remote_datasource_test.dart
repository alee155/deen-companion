import 'package:deen_companion/core/error/exceptions.dart';
import 'package:deen_companion/core/location/location_service.dart';
import 'package:deen_companion/core/network/api_endpoints.dart';
import 'package:deen_companion/features/prayer_times/data/datasources/prayer_times_remote_datasource.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../_support/dio_test_support.dart';

const _coords = Coordinates(latitude: 31.5204, longitude: 74.3587);

Map<String, dynamic> _bundle() => {
  'location': {
    'latitude': 31.52,
    'longitude': 74.36,
    'timezone': 'Asia/Karachi',
  },
  'method': {'id': 1, 'name': 'Karachi', 'school': 'hanafi', 'schoolId': 1},
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
      'hijri': null,
    },
  ],
};

Map<String, dynamic> _ok(Object? data) => {'success': true, 'data': data};

DioException _http(int status, Map<String, dynamic> body) => DioException(
  requestOptions: RequestOptions(path: '/'),
  type: DioExceptionType.badResponse,
  response: Response(
    statusCode: status,
    data: body,
    requestOptions: RequestOptions(path: '/'),
  ),
);

void main() {
  late MockDio dio;
  late PrayerTimesRemoteDataSourceImpl ds;

  setUpAll(() {
    registerFallbackValue(Options());
  });

  setUp(() {
    dio = MockDio();
    ds = PrayerTimesRemoteDataSourceImpl(dio, deviceId: () async => 'device-1');
  });

  When<Future<Response<dynamic>>> stubGet() => when(
    () => dio.get(
      any(),
      queryParameters: any(named: 'queryParameters'),
      options: any(named: 'options'),
    ),
  );

  Map<String, dynamic> lastQuery() =>
      verify(
            () => dio.get(
              any(),
              queryParameters: captureAny(named: 'queryParameters'),
              options: any(named: 'options'),
            ),
          ).captured.single
          as Map<String, dynamic>;

  Options lastOptions() =>
      verify(
            () => dio.get(
              any(),
              queryParameters: any(named: 'queryParameters'),
              options: captureAny(named: 'options'),
            ),
          ).captured.single
          as Options;

  group('guest times', () {
    test('sends coordinates and days, and the device id header', () async {
      stubGet().thenAnswer((_) async => okResponse(_ok(_bundle())));
      final r = await ds.guestTimes(_coords, days: 31);
      expect(r.toEntity().days, hasLength(1));

      verify(
        () => dio.get(
          ApiEndpoints.guestPrayerTimes,
          queryParameters: any(named: 'queryParameters'),
          options: any(named: 'options'),
        ),
      ).called(1);
    });

    test('omits method and school unless given', () async {
      stubGet().thenAnswer((_) async => okResponse(_ok(_bundle())));
      await ds.guestTimes(_coords, days: 31);
      final q = lastQuery();
      expect(q.containsKey('method'), isFalse);
      expect(q.containsKey('school'), isFalse);
      expect(q['latitude'], 31.5204);
      expect(q['days'], 31);
    });

    test('sends method and school when chosen', () async {
      stubGet().thenAnswer((_) async => okResponse(_ok(_bundle())));
      await ds.guestTimes(_coords, method: 3, school: 0, days: 1);
      final q = lastQuery();
      expect(q['method'], 3);
      expect(q['school'], 0, reason: 'zero is a real value, not "absent"');
    });

    test('carries X-Device-Id and a 30 second timeout', () async {
      stubGet().thenAnswer((_) async => okResponse(_ok(_bundle())));
      await ds.guestTimes(_coords, days: 1);
      final o = lastOptions();
      expect(o.headers?['X-Device-Id'], 'device-1');
      expect(o.receiveTimeout, const Duration(seconds: 30));
    });
  });

  test('guest month sends year and month', () async {
    stubGet().thenAnswer((_) async => okResponse(_ok(_bundle())));
    await ds.guestMonth(_coords, year: 2026, month: 10);
    final captured = verify(
      () => dio.get(
        captureAny(),
        queryParameters: captureAny(named: 'queryParameters'),
        options: any(named: 'options'),
      ),
    ).captured;
    expect(captured[0], ApiEndpoints.guestPrayerTimesMonth);
    final q = captured[1] as Map<String, dynamic>;
    expect(q['year'], 2026);
    expect(q['month'], 10);
  });

  group('account routes', () {
    test('account calls do not send the device id', () async {
      stubGet().thenAnswer((_) async => okResponse(_ok(_bundle())));
      await ds.accountTimes(days: 31);
      expect(
        lastOptions().headers?.containsKey('X-Device-Id') ?? false,
        isFalse,
      );
    });

    test('accountTimes asks for the days', () async {
      stubGet().thenAnswer((_) async => okResponse(_ok(_bundle())));
      await ds.accountTimes(days: 31);
      expect(lastQuery(), {'days': 31});
    });

    test('accountMonth', () async {
      stubGet().thenAnswer((_) async => okResponse(_ok(_bundle())));
      await ds.accountMonth(year: 2026, month: 11);
      expect(lastQuery(), {'year': 2026, 'month': 11});
    });

    test('getSavedSettings parses an empty account', () async {
      stubGet().thenAnswer(
        (_) async => okResponse(
          _ok({
            'location': null,
            'method': null,
            'defaults': {'method': 1, 'school': 1},
          }),
        ),
      );
      final s = await ds.getSavedSettings();
      expect(s.location, isNull);
      expect(s.method, isNull);
    });

    test('putLocation sends only the coordinates by default', () async {
      when(
        () => dio.put(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenAnswer((_) async => okResponse(_ok(_bundle())));
      await ds.putLocation(_coords);
      final body =
          verify(
                () => dio.put(
                  ApiEndpoints.prayerLocation,
                  data: captureAny(named: 'data'),
                  options: any(named: 'options'),
                ),
              ).captured.single
              as Map<String, dynamic>;
      expect(body, {'latitude': 31.5204, 'longitude': 74.3587});
    });

    test('putLocation includes method and school when given', () async {
      when(
        () => dio.put(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenAnswer((_) async => okResponse(_ok(_bundle())));
      await ds.putLocation(_coords, method: 3, school: 0);
      final body =
          verify(
                () => dio.put(
                  any(),
                  data: captureAny(named: 'data'),
                  options: any(named: 'options'),
                ),
              ).captured.single
              as Map<String, dynamic>;
      expect(body['method'], 3);
      expect(body['school'], 0);
    });

    test('clearLocation deletes the saved location', () async {
      when(
        () => dio.delete(any()),
      ).thenAnswer((_) async => okResponse(_ok(null)));
      await ds.clearLocation();
      verify(() => dio.delete(ApiEndpoints.prayerLocation)).called(1);
    });
  });

  group('cities and methods', () {
    test('searchCities sends the query and the device id', () async {
      stubGet().thenAnswer(
        (_) async => okResponse(
          _ok({
            'cities': [
              {
                'name': 'Lahore',
                'region': 'Punjab',
                'country': 'Pakistan',
                'countryCode': 'PK',
                'latitude': 31.558,
                'longitude': 74.3507,
                'timezone': 'Asia/Karachi',
              },
            ],
          }),
        ),
      );
      final cities = await ds.searchCities('Lahore');
      expect(cities.single.name, 'Lahore');
      expect(lastQuery()['q'], 'Lahore');
    });

    test('getMethods accepts a bare list', () async {
      stubGet().thenAnswer(
        (_) async => okResponse(
          _ok([
            {'id': 0, 'name': 'Shia'},
            {'id': 1, 'name': 'Karachi'},
          ]),
        ),
      );
      final m = await ds.getMethods();
      expect(m.map((e) => e.id), [0, 1]);
    });

    test('getMethods accepts {methods: [...]}', () async {
      stubGet().thenAnswer(
        (_) async => okResponse(
          _ok({
            'methods': [
              {'id': 3, 'name': 'MWL'},
            ],
          }),
        ),
      );
      expect((await ds.getMethods()).single.name, 'MWL');
    });
  });

  group('errors', () {
    test('keeps the status and the machine-readable code', () async {
      stubGet().thenThrow(
        _http(409, {
          'success': false,
          'statusCode': 409,
          'message': 'Set your location first',
          'code': 'LOCATION_NOT_SET',
        }),
      );
      await expectLater(
        ds.accountTimes(days: 1),
        throwsA(
          isA<ServerException>()
              .having((e) => e.statusCode, 'status', 409)
              .having((e) => e.code, 'code', 'LOCATION_NOT_SET'),
        ),
      );
    });

    test('a validation list becomes one message', () async {
      stubGet().thenThrow(
        _http(400, {
          'success': false,
          'message': ['method must be one of the following values: 0, 1'],
        }),
      );
      await expectLater(
        ds.guestTimes(_coords, method: 6, days: 1),
        throwsA(
          isA<ServerException>().having(
            (e) => e.message,
            'message',
            contains('method must be one of'),
          ),
        ),
      );
    });

    test('a connection error is a NetworkException', () async {
      stubGet().thenThrow(dioError());
      await expectLater(
        ds.accountTimes(days: 1),
        throwsA(isA<NetworkException>()),
      );
    });

    test('a malformed body is a ServerException', () async {
      stubGet().thenAnswer((_) async => okResponse(_ok('nope')));
      await expectLater(
        ds.accountTimes(days: 1),
        throwsA(isA<ServerException>()),
      );
    });

    test('success:false without an HTTP error is a ServerException', () async {
      stubGet().thenAnswer(
        (_) async => okResponse({'success': false, 'message': 'x'}),
      );
      await expectLater(
        ds.accountTimes(days: 1),
        throwsA(isA<ServerException>()),
      );
    });
  });
}
