import 'package:deen_companion/core/error/exceptions.dart';
import 'package:deen_companion/core/network/api_endpoints.dart';
import 'package:deen_companion/features/qibla/data/datasources/qibla_remote_datasource.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDio extends Mock implements Dio {}

void main() {
  late _MockDio dio;
  late QiblaRemoteDataSourceImpl ds;
  setUp(() {
    dio = _MockDio();
    ds = QiblaRemoteDataSourceImpl(dio);
  });

  Response<dynamic> ok(dynamic d) => Response(
    requestOptions: RequestOptions(path: ''),
    data: d,
  );

  test(
    'unwraps the UmmahAPI envelope and requests the lat/lng endpoint',
    () async {
      when(() => dio.get(any())).thenAnswer(
        (_) async => ok({
          'success': true,
          'service': 'qibla',
          'data': {
            'qibla_direction': 118.2,
            'compass_bearing': 'ESE',
            'distance_km': 4000.5,
            'distance_miles': 2485.7,
            'note': 'n',
          },
        }),
      );
      final m = await ds.getQibla(51.5, -0.12);
      expect(m.qiblaDirection, 118.2);
      verify(
        () => dio.get(ApiEndpoints.qibla(lat: 51.5, lng: -0.12)),
      ).called(1);
    },
  );

  test('endpoint carries both coordinates as query parameters', () {
    final uri = Uri.parse(ApiEndpoints.qibla(lat: -33.86, lng: 151.2));
    expect(uri.queryParameters, {'lat': '-33.86', 'lng': '151.2'});
  });

  test('DioException -> ServerException(message)', () async {
    when(() => dio.get(any())).thenThrow(
      DioException(
        requestOptions: RequestOptions(path: ''),
        message: 'timeout',
      ),
    );
    expect(
      () => ds.getQibla(0, 0),
      throwsA(isA<ServerException>().having((e) => e.message, 'm', 'timeout')),
    );
  });

  test('envelope missing data surfaces a TypeError', () async {
    when(() => dio.get(any())).thenAnswer((_) async => ok({'success': true}));
    expect(() => ds.getQibla(0, 0), throwsA(isA<TypeError>()));
  });
}
