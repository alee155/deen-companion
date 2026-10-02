import 'package:deen_companion/core/error/exceptions.dart';
import 'package:deen_companion/core/network/api_endpoints.dart';
import 'package:deen_companion/features/zakat/data/datasources/zakat_remote_datasource.dart';
import 'package:deen_companion/features/zakat/data/models/zakat_calculation_model.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../_fixtures.dart';

class _MockDio extends Mock implements Dio {}

Response<dynamic> _ok(Object? d) => Response(
  requestOptions: RequestOptions(path: ''),
  data: {'success': true, 'service': 'zakat', 'data': d},
);

DioException _err() =>
    DioException(requestOptions: RequestOptions(path: ''), message: 'net');

void main() {
  late _MockDio dio;
  late ZakatRemoteDataSourceImpl ds;
  setUp(() {
    dio = _MockDio();
    ds = ZakatRemoteDataSourceImpl(dio);
  });

  const request = ZakatCalculateRequestModel(
    nisabStandard: 'gold',
    cash: 100,
    goldGrams: 0,
    silverGrams: 0,
    stocks: 0,
    businessGoods: 0,
    otherInvestments: 0,
    liabilities: 0,
  );

  test('getInfo', () async {
    when(() => dio.get(any())).thenAnswer((_) async => _ok(infoJson()));
    expect((await ds.getInfo()).hawl, 'one year');
    verify(() => dio.get(ApiEndpoints.zakatInfo)).called(1);
  });

  test('getNisab passes optional prices through the endpoint builder', () async {
    when(() => dio.get(any())).thenAnswer((_) async => _ok(nisabJson()));
    await ds.getNisab(goldPricePerGram: 65.5, silverPricePerGram: 0.8);
    verify(
      () => dio.get(ApiEndpoints.zakatNisab(goldPricePerGram: 65.5, silverPricePerGram: 0.8)),
    ).called(1);
  });

  test('calculate POSTs the request json and parses the response', () async {
    when(() => dio.post(any(), data: any(named: 'data'))).thenAnswer((_) async => _ok(calcJson()));
    final r = await ds.calculate(request);
    expect(r.zakatDue, 412.51);
    final captured = verify(
      () => dio.post(ApiEndpoints.zakatCalculate, data: captureAny(named: 'data')),
    ).captured.single as Map<String, dynamic>;
    expect(captured['cash'], 100);
    expect(captured.containsKey('gold_price_per_gram'), isFalse);
  });

  test('calculateAgriculture POSTs and parses', () async {
    when(() => dio.post(any(), data: any(named: 'data'))).thenAnswer((_) async => _ok(agriJson()));
    final r = await ds.calculateAgriculture(
      const ZakatAgricultureRequestModel(value: 1000, waterSource: 'rain'),
    );
    expect(r.zakatDue, 100);
    verify(
      () => dio.post(ApiEndpoints.zakatAgriculture, data: {'value': 1000.0, 'water_source': 'rain'}),
    ).called(1);
  });

  test('DioException -> ServerException for all four calls', () async {
    when(() => dio.get(any())).thenThrow(_err());
    when(() => dio.post(any(), data: any(named: 'data'))).thenThrow(_err());
    await expectLater(ds.getInfo(), throwsA(isA<ServerException>()));
    await expectLater(ds.getNisab(), throwsA(isA<ServerException>()));
    await expectLater(ds.calculate(request), throwsA(isA<ServerException>()));
    await expectLater(
      ds.calculateAgriculture(const ZakatAgricultureRequestModel(value: 1, waterSource: 'rain')),
      throwsA(isA<ServerException>().having((e) => e.message, 'm', 'net')),
    );
  });
}
