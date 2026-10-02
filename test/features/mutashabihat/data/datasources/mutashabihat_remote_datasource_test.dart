import 'package:deen_companion/core/error/exceptions.dart';
import 'package:deen_companion/core/network/api_endpoints.dart';
import 'package:deen_companion/features/mutashabihat/data/datasources/mutashabihat_remote_datasource.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../_support/dio_test_support.dart';
import '../../../_support/mutashabihat_fixtures.dart';
import '../../../_support/quran_fixtures.dart' show envelope;

void main() {
  late MockDio dio;
  late MutashabihatRemoteDataSourceImpl ds;

  setUpAll(registerDioFallbacks);
  setUp(() {
    dio = MockDio();
    ds = MutashabihatRemoteDataSourceImpl(dio);
  });

  test('getInfo and getRandom parse their payloads', () async {
    stubGet(dio, envelope(infoJson()));
    expect((await ds.getInfo()).totalEntries, 1000);
    verify(() => dio.get(ApiEndpoints.mutashabihat)).called(1);

    stubGet(dio, envelope(entryJson()));
    expect((await ds.getRandom()).similarVerses, hasLength(2));
    verify(() => dio.get(ApiEndpoints.mutashabihatRandom)).called(1);
  });

  group('getByAyah', () {
    test('parses a 200 response and asks Dio to accept 4xx statuses', () async {
      stubGetWithOptions(dio, envelope(entryJson()));
      final e = await ds.getByAyah(2, 1);
      expect(e.verse.verseKey, '2:1');

      final captured = verify(
        () => dio.get(
          ApiEndpoints.mutashabihatByAyah(2, 1),
          options: captureAny(named: 'options'),
        ),
      ).captured.single;
      final validate =
          (captured as dynamic).validateStatus as bool Function(int?);
      expect(validate(404), isTrue);
      expect(validate(200), isTrue);
      expect(validate(500), isFalse);
      expect(validate(null), isFalse);
    });

    test('404 becomes NotFoundException (not ServerException)', () async {
      stubGetWithOptions(dio, {'success': false}, status: 404);
      await expectLater(ds.getByAyah(1, 1), throwsA(isA<NotFoundException>()));
    });

    test('DioException becomes ServerException', () async {
      when(
        () => dio.get(any(), options: any(named: 'options')),
      ).thenThrow(dioError('x'));
      await expectLater(ds.getByAyah(1, 1), throwsA(isA<ServerException>()));
    });
  });

  group('getSurahPage', () {
    test('parses a normal page', () async {
      stubGetWithOptions(dio, envelope(surahPageJson(page: 2)));
      final p = await ds.getSurahPage(2, 2);
      expect(p.page, 2);
      verify(
        () => dio.get(
          ApiEndpoints.mutashabihatBySurah(2, page: 2),
          options: any(named: 'options'),
        ),
      ).called(1);
    });

    test(
      '404 yields an empty placeholder page for that surah instead of throwing',
      () async {
        stubGetWithOptions(dio, {'success': false}, status: 404);
        final p = await ds.getSurahPage(105, 1);

        expect(p.surah, 105);
        expect(p.entries, isEmpty);
        expect(p.total, 0);
        expect(p.totalPages, 0);
        expect(p.toEntity().hasMore, isFalse);
      },
    );

    test('DioException becomes ServerException', () async {
      when(
        () => dio.get(any(), options: any(named: 'options')),
      ).thenThrow(dioError('x'));
      await expectLater(ds.getSurahPage(1, 1), throwsA(isA<ServerException>()));
    });
  });

  test('getInfo/getRandom DioException becomes ServerException', () async {
    stubGetThrows(dio, dioError('x'));
    await expectLater(ds.getInfo(), throwsA(isA<ServerException>()));
    await expectLater(ds.getRandom(), throwsA(isA<ServerException>()));
  });
}
