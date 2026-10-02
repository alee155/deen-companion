import 'package:deen_companion/core/error/exceptions.dart';
import 'package:deen_companion/core/network/api_endpoints.dart';
import 'package:deen_companion/features/asma_ul_husna/data/datasources/asma_ul_husna_remote_datasource.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../_support/dio_test_support.dart';
import '../../../_support/names_fixtures.dart';
import '../../../_support/quran_fixtures.dart' show envelope;

void main() {
  late MockDio dio;
  late AsmaUlHusnaRemoteDataSourceImpl ds;
  setUp(() {
    dio = MockDio();
    ds = AsmaUlHusnaRemoteDataSourceImpl(dio);
  });

  test('getAllNames reads data.names', () async {
    stubGet(
      dio,
      envelope({
        'names': [asmaNameJson(n: 1), asmaNameJson(n: 2)],
      }),
    );
    expect((await ds.getAllNames()).map((n) => n.number), [1, 2]);
    verify(() => dio.get(ApiEndpoints.asmaUlHusna)).called(1);
  });

  test('getDailyNames hits the daily URL for the given day', () async {
    stubGet(dio, envelope(asmaDailyJson(day: 4)));
    expect((await ds.getDailyNames(4)).dayNumber, 4);
    verify(() => dio.get(ApiEndpoints.asmaUlHusnaDaily(4))).called(1);
  });

  test('search reads data.results and encodes the query', () async {
    stubGet(
      dio,
      envelope({
        'results': [asmaNameJson()],
      }),
    );
    expect(await ds.search('mercy & grace'), hasLength(1));
    verify(
      () => dio.get(ApiEndpoints.asmaUlHusnaSearch('mercy & grace')),
    ).called(1);
  });

  test('DioException -> ServerException for each call', () async {
    stubGetThrows(dio, dioError('e'));
    await expectLater(ds.getAllNames(), throwsA(isA<ServerException>()));
    await expectLater(ds.getDailyNames(1), throwsA(isA<ServerException>()));
    await expectLater(ds.search('a'), throwsA(isA<ServerException>()));
  });

  test('missing wrapper keys raise cast errors', () async {
    stubGet(dio, envelope({'unexpected': 1}));
    expect(ds.getAllNames(), throwsA(isA<TypeError>()));
    expect(ds.search('a'), throwsA(isA<TypeError>()));
  });
}
