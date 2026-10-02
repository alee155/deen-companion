import 'package:deen_companion/core/error/exceptions.dart';
import 'package:deen_companion/core/network/api_endpoints.dart';
import 'package:deen_companion/features/duas/data/datasources/dua_remote_datasource.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../_support/dio_test_support.dart';
import '../../../_support/dua_fixtures.dart';
import '../../../_support/quran_fixtures.dart' show envelope;

void main() {
  late MockDio dio;
  late DuaRemoteDataSourceImpl ds;
  setUp(() {
    dio = MockDio();
    ds = DuaRemoteDataSourceImpl(dio);
  });

  test('getBundle parses envelope', () async {
    stubGet(dio, envelope(bundleJson()));
    final b = await ds.getBundle();
    expect(b.duas, hasLength(3));
    verify(() => dio.get(ApiEndpoints.duas)).called(1);
  });

  test('search requests the search URL for the query', () async {
    stubGet(dio, envelope(duaSearchJson()));
    final r = await ds.search('morning');
    expect(r.results.single.id, 9);
    verify(() => dio.get(ApiEndpoints.duasSearch('morning'))).called(1);
  });

  test('DioException becomes ServerException', () async {
    stubGetThrows(dio, dioError('offline'));
    await expectLater(
      ds.getBundle(),
      throwsA(
        isA<ServerException>().having((e) => e.message, 'message', 'offline'),
      ),
    );
    await expectLater(ds.search('x'), throwsA(isA<ServerException>()));
  });

  test(
    'malformed payload surfaces as a cast error (not ServerException)',
    () async {
      stubGet(dio, envelope({'total': 1}));
      expect(ds.getBundle(), throwsA(isA<TypeError>()));
    },
  );
}
