import 'package:deen_companion/core/error/exceptions.dart';
import 'package:deen_companion/core/network/api_endpoints.dart';
import 'package:deen_companion/features/quran/data/datasources/quran_remote_datasource.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../_support/dio_test_support.dart';
import '../../../_support/quran_fixtures.dart';

void main() {
  late MockDio dio;
  late QuranRemoteDataSourceImpl ds;

  setUp(() {
    dio = MockDio();
    ds = QuranRemoteDataSourceImpl(dio);
  });

  test(
    'getQuranMeta unwraps the envelope and hits the meta endpoint',
    () async {
      stubGet(dio, envelope(metaJson()));
      final meta = await ds.getQuranMeta();
      expect(meta.totalSurahs, 114);
      verify(() => dio.get(ApiEndpoints.quranMeta)).called(1);
    },
  );

  test('getSurahList reads data.surahs', () async {
    stubGet(
      dio,
      envelope({
        'surahs': [surahJson(number: 1), surahJson(number: 2)],
      }),
    );
    final list = await ds.getSurahList();
    expect(list.map((s) => s.number), [1, 2]);
    verify(() => dio.get(ApiEndpoints.quranSurahs)).called(1);
  });

  test('getSurahList with no surahs key fails with a cast error', () async {
    stubGet(dio, envelope({'other': []}));
    expect(ds.getSurahList(), throwsA(isA<TypeError>()));
  });

  test('searchQuran builds URL from query, translation and limit', () async {
    stubGet(dio, envelope(searchResponseJson()));
    final res = await ds.searchQuran(
      'throne',
      translation: 'pickthall',
      limit: 5,
    );
    expect(res.results, hasLength(1));
    verify(
      () => dio.get(
        ApiEndpoints.quranSearch('throne', translation: 'pickthall', limit: 5),
      ),
    ).called(1);
  });

  test('getJuz and getMushafPage parse their payloads', () async {
    stubGet(dio, envelope(juzJson(number: 7)));
    expect((await ds.getJuz(7)).juzNumber, 7);
    verify(() => dio.get(ApiEndpoints.quranJuz(7))).called(1);

    stubGet(dio, envelope(pageJson(page: 9)));
    expect((await ds.getMushafPage(9)).page, 9);
    verify(() => dio.get(ApiEndpoints.quranMushafPage(9))).called(1);
  });

  test('DioException is mapped to ServerException with the message', () async {
    stubGetThrows(dio, dioError('timeout'));
    await expectLater(
      ds.getQuranMeta(),
      throwsA(
        isA<ServerException>().having((e) => e.message, 'message', 'timeout'),
      ),
    );
    await expectLater(ds.getSurahList(), throwsA(isA<ServerException>()));
    await expectLater(ds.searchQuran('x'), throwsA(isA<ServerException>()));
    await expectLater(ds.getJuz(1), throwsA(isA<ServerException>()));
    await expectLater(ds.getMushafPage(1), throwsA(isA<ServerException>()));
  });

  test('envelope with null data fails rather than returning garbage', () async {
    stubGet(dio, envelope(null));
    expect(ds.getJuz(1), throwsA(isA<TypeError>()));
  });
}
