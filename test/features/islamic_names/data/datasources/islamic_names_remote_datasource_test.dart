import 'package:deen_companion/core/error/exceptions.dart';
import 'package:deen_companion/core/network/api_endpoints.dart';
import 'package:deen_companion/features/islamic_names/data/datasources/islamic_names_remote_datasource.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../_support/dio_test_support.dart';
import '../../../_support/names_fixtures.dart';
import '../../../_support/quran_fixtures.dart' show envelope;

void main() {
  late MockDio dio;
  late IslamicNamesRemoteDataSourceImpl ds;
  setUp(() {
    dio = MockDio();
    ds = IslamicNamesRemoteDataSourceImpl(dio);
  });

  test('reads data.names from the all-names endpoint', () async {
    stubGet(
      dio,
      envelope({
        'names': [islamicNameJson(), islamicNameJson(id: 2, root: null)],
      }),
    );
    final names = await ds.getAllNames();
    expect(names.map((n) => n.id), [1, 2]);
    expect(names.last.root, isNull);
    verify(() => dio.get(ApiEndpoints.islamicNamesAll)).called(1);
  });

  test('empty names list is fine', () async {
    stubGet(dio, envelope({'names': []}));
    expect(await ds.getAllNames(), isEmpty);
  });

  test('DioException -> ServerException with message', () async {
    stubGetThrows(dio, dioError('nope'));
    await expectLater(
      ds.getAllNames(),
      throwsA(
        isA<ServerException>().having((e) => e.message, 'message', 'nope'),
      ),
    );
  });

  test('one malformed entry fails the whole load with a cast error', () async {
    stubGet(
      dio,
      envelope({
        'names': [
          islamicNameJson(),
          {'id': 2},
        ],
      }),
    );
    expect(ds.getAllNames(), throwsA(isA<TypeError>()));
  });
}
