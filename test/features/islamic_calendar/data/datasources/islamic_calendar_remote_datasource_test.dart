import 'package:deen_companion/core/error/exceptions.dart';
import 'package:deen_companion/core/network/api_endpoints.dart';
import 'package:deen_companion/features/islamic_calendar/data/datasources/islamic_calendar_remote_datasource.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../_fixtures.dart';

class _MockDio extends Mock implements Dio {}

Response<dynamic> _ok(Object? data) =>
    Response(requestOptions: RequestOptions(path: ''), data: data);

Map<String, dynamic> _env(Object data) => {
  'success': true,
  'service': 's',
  'data': data,
};

DioException _dioErr() =>
    DioException(requestOptions: RequestOptions(path: ''), message: 'down');

void main() {
  late _MockDio dio;
  late IslamicCalendarRemoteDataSourceImpl ds;
  setUp(() {
    dio = _MockDio();
    ds = IslamicCalendarRemoteDataSourceImpl(dio);
  });

  test('getTodayHijri hits today endpoint and unwraps', () async {
    when(() => dio.get(any())).thenAnswer((_) async => _ok(_env(conversionJson())));
    final m = await ds.getTodayHijri();
    expect(m.hijri.year, 1448);
    verify(() => dio.get(ApiEndpoints.todayHijri)).called(1);
  });

  test('getHijriDate (g2h) builds the endpoint from y/m/d', () async {
    when(() => dio.get(any())).thenAnswer((_) async => _ok(_env(conversionJson())));
    await ds.getHijriDate(2026, 6, 16);
    verify(() => dio.get(ApiEndpoints.hijriDate(year: 2026, month: 6, day: 16))).called(1);
  });

  test('getGregorianDate (h2g) builds the endpoint from y/m/d', () async {
    when(() => dio.get(any())).thenAnswer((_) async => _ok(_env(conversionJson())));
    await ds.getGregorianDate(1448, 1, 1);
    verify(() => dio.get(ApiEndpoints.gregorianDate(year: 1448, month: 1, day: 1))).called(1);
  });

  test('getIslamicMonths unwraps data.months', () async {
    when(() => dio.get(any())).thenAnswer(
      (_) async => _ok(_env({'months': [monthJson(1), monthJson(2)]})),
    );
    final months = await ds.getIslamicMonths();
    expect(months.map((m) => m.number), [1, 2]);
  });

  test('getIslamicMonths without a months key throws', () async {
    when(() => dio.get(any())).thenAnswer((_) async => _ok(_env({})));
    expect(() => ds.getIslamicMonths(), throwsA(isA<TypeError>()));
  });

  test('getIslamicEvents parses the bundle', () async {
    when(() => dio.get(any())).thenAnswer((_) async => _ok(_env(eventsBundleJson())));
    final b = await ds.getIslamicEvents();
    expect(b.events, hasLength(2));
  });

  test('every call maps DioException to ServerException', () async {
    when(() => dio.get(any())).thenThrow(_dioErr());
    final calls = <Future<Object?> Function()>[
      ds.getTodayHijri,
      () => ds.getHijriDate(2026, 1, 1),
      () => ds.getGregorianDate(1448, 1, 1),
      ds.getIslamicMonths,
      ds.getIslamicEvents,
    ];
    for (final call in calls) {
      await expectLater(
        call(),
        throwsA(isA<ServerException>().having((e) => e.message, 'message', 'down')),
      );
    }
  });
}
