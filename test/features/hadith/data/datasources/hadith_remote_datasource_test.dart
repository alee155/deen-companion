import 'package:deen_companion/core/error/exceptions.dart';
import 'package:deen_companion/core/network/api_endpoints.dart';
import 'package:deen_companion/features/hadith/data/datasources/hadith_remote_datasource.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../_support/dio_test_support.dart';
import '../../../_support/hadith_fixtures.dart';
import '../../../_support/quran_fixtures.dart' show envelope;

void main() {
  late MockDio dio;
  late HadithRemoteDataSourceImpl ds;
  setUp(() {
    dio = MockDio();
    ds = HadithRemoteDataSourceImpl(dio);
  });

  test('getCollections reads data.collections', () async {
    stubGet(
      dio,
      envelope({
        'collections': [
          hadithCollectionJson(),
          hadithCollectionJson(key: 'muslim'),
        ],
      }),
    );
    final list = await ds.getCollections();
    expect(list.map((c) => c.key), ['bukhari', 'muslim']);
    verify(() => dio.get(ApiEndpoints.hadithCollections)).called(1);
  });

  test('getHadithPage requests the right page URL', () async {
    stubGet(dio, envelope(hadithPageJson(page: 2)));
    final page = await ds.getHadithPage('bukhari', 2);
    expect(page.page, 2);
    verify(() => dio.get(ApiEndpoints.hadithPage('bukhari', 2))).called(1);
  });

  test('getRandomHadith parses a single hadith', () async {
    stubGet(dio, envelope(hadithJson(n: 3)));
    expect((await ds.getRandomHadith()).hadithNumber, 3);
    verify(() => dio.get(ApiEndpoints.hadithRandom)).called(1);
  });

  test('search forwards collection and limit and reads data.hadiths', () async {
    stubGet(
      dio,
      envelope({
        'hadiths': [hadithJson(), hadithJson(n: 2)],
      }),
    );
    final res = await ds.search('intent', collection: 'muslim', limit: 10);
    expect(res, hasLength(2));
    verify(
      () => dio.get(
        ApiEndpoints.hadithSearch('intent', collection: 'muslim', limit: 10),
      ),
    ).called(1);
  });

  test('search with empty hadiths list returns empty', () async {
    stubGet(dio, envelope({'hadiths': []}));
    expect(await ds.search('x'), isEmpty);
  });

  test('DioException is wrapped in ServerException for every call', () async {
    stubGetThrows(dio, dioError('down'));
    await expectLater(ds.getCollections(), throwsA(isA<ServerException>()));
    await expectLater(
      ds.getHadithPage('a', 1),
      throwsA(isA<ServerException>()),
    );
    await expectLater(ds.getRandomHadith(), throwsA(isA<ServerException>()));
    await expectLater(
      ds.search('a'),
      throwsA(isA<ServerException>().having((e) => e.message, 'm', 'down')),
    );
  });

  test('missing wrapper key surfaces a cast error', () async {
    stubGet(dio, envelope({'wrong': []}));
    expect(ds.getCollections(), throwsA(isA<TypeError>()));
    expect(ds.search('a'), throwsA(isA<TypeError>()));
  });
}
