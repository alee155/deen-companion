import 'dart:convert';

import 'package:deen_companion/core/constants/app_constants.dart';
import 'package:deen_companion/core/error/exceptions.dart';
import 'package:deen_companion/core/error/failures.dart';
import 'package:deen_companion/core/network/network_info.dart';
import 'package:deen_companion/core/usecase/usecase.dart';
import 'package:deen_companion/features/daily_content/data/daily_content_remote_source.dart';
import 'package:deen_companion/features/daily_content/data/daily_content_store.dart';
import 'package:deen_companion/features/daily_content/data/repositories/daily_content_repository_impl.dart';
import 'package:deen_companion/features/daily_content/domain/daily_content_selector.dart';
import 'package:deen_companion/features/daily_content/domain/entities/daily_content.dart';
import 'package:deen_companion/features/hadith/data/models/hadith_model.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/in_memory_storage_service.dart';

class MockDio extends Mock implements Dio {}

class MockRemote extends Mock implements DailyContentRemoteSource {}

class FakeNetwork implements NetworkInfo {
  bool connected;
  FakeNetwork(this.connected);
  @override
  Future<bool> get isConnected async => connected;
}

Response<dynamic> ok(Object data) => Response(
  data: data,
  requestOptions: RequestOptions(path: '/'),
  statusCode: 200,
);

Map<String, dynamic> ayahPayload({
  String translation = 'Ever-Living,1 the Self-Sustaining.2',
}) => {
  'data': {
    'surah': {
      'number': 2,
      'name_english': 'Al-Baqarah',
      'name_arabic': 'البقرة',
    },
    'verse': {
      'ayah': 255,
      'arabic': 'ar',
      'translations': {'sahih_international': translation},
    },
  },
};

const _hadithModel = HadithModel(
  id: 'nawawi:1',
  collection: 'nawawi',
  collectionName: 'Forty Hadith',
  hadithNumber: 1,
  arabic: 'ar',
  english: 'en',
  grade: 'Sahih',
);

const _ayah = DailyAyah(
  surahNumber: 2,
  surahNameEnglish: 'Al-Baqarah',
  surahNameArabic: 'ب',
  ayahNumber: 255,
  arabic: 'a',
  translation: 't',
);

void main() {
  const box = AppConstants.dailyContentBoxName;

  group('DailyContentRemoteSource', () {
    late MockDio dio;
    late DailyContentRemoteSource remote;
    setUp(() {
      dio = MockDio();
      remote = DailyContentRemoteSource(dio);
    });

    test('getAyah parses payload and strips footnote markers', () async {
      when(() => dio.get(any())).thenAnswer((_) async => ok(ayahPayload()));
      final a = await remote.getAyah(2, 255);
      expect(a.surahNumber, 2);
      expect(a.ayahNumber, 255);
      expect(a.surahNameEnglish, 'Al-Baqarah');
      expect(a.translation, 'Ever-Living, the Self-Sustaining.');
    });

    test(
      'footnote stripping leaves numbers inside words/text intact',
      () async {
        when(() => dio.get(any())).thenAnswer(
          (_) async =>
              ok(ayahPayload(translation: 'On the 3 days he said 100 things.')),
        );
        final a = await remote.getAyah(1, 1);
        expect(a.translation, 'On the 3 days he said 100 things.');
      },
    );

    test(
      'missing sahih_international translation becomes empty string',
      () async {
        final p = ayahPayload();
        ((p['data'] as Map)['verse'] as Map)['translations'] =
            <String, dynamic>{};
        when(() => dio.get(any())).thenAnswer((_) async => ok(p));
        expect((await remote.getAyah(1, 1)).translation, '');
      },
    );

    test('DioException is mapped to ServerException', () {
      when(() => dio.get(any())).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/'),
          message: 'timeout',
        ),
      );
      expect(
        remote.getAyah(1, 1),
        throwsA(
          isA<ServerException>().having((e) => e.message, 'message', 'timeout'),
        ),
      );
      expect(remote.getHadith('nawawi', 1), throwsA(isA<ServerException>()));
    });

    test('malformed ayah payload throws a cast error (not swallowed)', () {
      when(() => dio.get(any())).thenAnswer((_) async => ok({'data': {}}));
      expect(remote.getAyah(1, 1), throwsA(isA<TypeError>()));
    });

    test('getHadith parses via HadithModel', () async {
      when(
        () => dio.get(any()),
      ).thenAnswer((_) async => ok({'data': _hadithModel.toJson()}));
      final h = await remote.getHadith('nawawi', 1);
      expect(h.collectionName, 'Forty Hadith');
      expect(h.hadithNumber, 1);
    });
  });

  group('NotificationSlot / DeliveredNotification JSON', () {
    test('slot round trip incl. default debug', () {
      const s = NotificationSlot(
        id: '2025-01-01',
        dateKey: '2025-01-01',
        epochMillis: 1000,
      );
      final back = NotificationSlot.fromJson(s.toJson());
      expect(back.id, s.id);
      expect(back.epochMillis, 1000);
      expect(back.debug, isFalse);
      expect(back.time, DateTime.fromMillisecondsSinceEpoch(1000));
    });

    test('slot fromJson tolerates missing debug but not missing id', () {
      expect(
        NotificationSlot.fromJson({
          'id': 'a',
          'dateKey': 'b',
          'epochMillis': 1,
        }).debug,
        isFalse,
      );
      expect(
        () => NotificationSlot.fromJson({'dateKey': 'b', 'epochMillis': 1}),
        throwsA(isA<TypeError>()),
      );
    });

    test('delivered round trip', () {
      const d = DeliveredNotification(
        id: 'debug-1',
        dateKey: '2025-01-01',
        deliveredAtMillis: 5000,
        debug: true,
      );
      final back = DeliveredNotification.fromJson(d.toJson());
      expect(back.debug, isTrue);
      expect(back.deliveredAt, DateTime.fromMillisecondsSinceEpoch(5000));
    });
  });

  group('DailyContentStore', () {
    late InMemoryStorageService storage;
    late DailyContentStore store;
    setUp(() {
      storage = InMemoryStorageService();
      store = DailyContentStore(storage);
    });

    test('write/read content round trip', () async {
      await store.writeContent('2025-01-01', _ayah, _hadithModel);
      final c = store.readContent('2025-01-01')!;
      expect(c.dateKey, '2025-01-01');
      expect(c.ayah.verseKey, '2:255');
      expect(c.hadith.collectionName, 'Forty Hadith');
      expect(store.readContent('2025-01-02'), isNull);
    });

    test('corrupted or partial content reads as null', () async {
      await storage.put(box, 'content:a', 'garbage');
      await storage.put(box, 'content:b', jsonEncode({'ayah': {}}));
      expect(store.readContent('a'), isNull);
      expect(store.readContent('b'), isNull);
    });

    test('pruneContentBefore removes only older content keys', () async {
      for (final k in ['2025-01-01', '2025-01-10', '2025-01-20']) {
        await store.writeContent(k, _ayah, _hadithModel);
      }
      await store.writeSlots([
        const NotificationSlot(id: 'x', dateKey: '2024-01-01', epochMillis: 1),
      ]);
      await store.pruneContentBefore('2025-01-10');
      expect(store.readContent('2025-01-01'), isNull);
      expect(store.readContent('2025-01-10'), isNotNull);
      expect(store.readContent('2025-01-20'), isNotNull);
      expect(store.readSlots(), hasLength(1));
    });

    test('slots: write/read/slotById, corrupted -> empty', () async {
      expect(store.readSlots(), isEmpty);
      await store.writeSlots([
        const NotificationSlot(id: 'a', dateKey: 'd1', epochMillis: 1),
        const NotificationSlot(
          id: 'b',
          dateKey: 'd2',
          epochMillis: 2,
          debug: true,
        ),
      ]);
      expect(store.readSlots().map((s) => s.id), ['a', 'b']);
      expect(store.slotById('b')!.debug, isTrue);
      expect(store.slotById('zzz'), isNull);
      await storage.put(box, 'slots', '[{"id": 1}]');
      expect(store.readSlots(), isEmpty);
      await storage.put(box, 'slots', 'nope');
      expect(store.slotById('a'), isNull);
    });

    test('delivered: write/read, corrupted -> empty', () async {
      await store.writeDelivered([
        const DeliveredNotification(
          id: 'a',
          dateKey: 'd',
          deliveredAtMillis: 3,
        ),
      ]);
      expect(store.readDelivered().single.deliveredAtMillis, 3);
      await storage.put(box, 'delivered', '{');
      expect(store.readDelivered(), isEmpty);
    });

    test('read ids: write/read, corrupted -> empty set', () async {
      expect(store.readIds(), isEmpty);
      await store.writeReadIds({'a', 'b'});
      expect(store.readIds(), {'a', 'b'});
      await storage.put(box, 'read', 'oops');
      expect(store.readIds(), isEmpty);
    });

    test('resetHistoryIfOutdated wipes history once, keeps content', () async {
      await store.writeSlots([
        const NotificationSlot(id: 'a', dateKey: 'd', epochMillis: 1),
      ]);
      await store.writeDelivered([
        const DeliveredNotification(
          id: 'a',
          dateKey: 'd',
          deliveredAtMillis: 1,
        ),
      ]);
      await store.writeReadIds({'a'});
      await store.writeContent('2025-01-01', _ayah, _hadithModel);

      await store.resetHistoryIfOutdated();
      expect(store.readSlots(), isEmpty);
      expect(store.readDelivered(), isEmpty);
      expect(store.readIds(), isEmpty);
      expect(store.readContent('2025-01-01'), isNotNull);

      // Second call is a no-op: new history survives.
      await store.writeReadIds({'z'});
      await store.resetHistoryIfOutdated();
      expect(store.readIds(), {'z'});
    });
  });

  group('DailyContentRepositoryImpl', () {
    late MockRemote remote;
    late InMemoryStorageService storage;
    late DailyContentStore store;
    late FakeNetwork network;
    late DailyContentRepositoryImpl repo;

    setUp(() {
      remote = MockRemote();
      storage = InMemoryStorageService();
      store = DailyContentStore(storage);
      network = FakeNetwork(true);
      repo = DailyContentRepositoryImpl(
        remote: remote,
        store: store,
        networkInfo: network,
      );
    });

    void stubRemote() {
      when(() => remote.getAyah(any(), any())).thenAnswer((_) async => _ayah);
      when(
        () => remote.getHadith(any(), any()),
      ).thenAnswer((_) async => _hadithModel);
    }

    test(
      'fetch hits network with selector-chosen verse and hadith, caches',
      () async {
        stubRemote();
        final r = await repo.fetch('2024-01-02');
        final c = (r as Success<DailyContent>).data;
        expect(c.dateKey, '2024-01-02');
        verify(() => remote.getAyah(2, 286)).called(1);
        verify(() => remote.getHadith('nawawi', 2)).called(1);
        expect(repo.getCached('2024-01-02'), isNotNull);
      },
    );

    test('second fetch is served from cache without network', () async {
      stubRemote();
      await repo.fetch('2024-01-02');
      network.connected = false;
      final r = await repo.fetch('2024-01-02');
      expect(r, isA<Success<DailyContent>>());
      verify(() => remote.getAyah(any(), any())).called(1);
    });

    test('invalid date key -> UnexpectedFailure, no network', () async {
      final r = await repo.fetch('garbage');
      expect((r as Error).failure, isA<UnexpectedFailure>());
      verifyNever(() => remote.getAyah(any(), any()));
    });

    test('offline and uncached -> NetworkFailure', () async {
      network.connected = false;
      final r = await repo.fetch('2024-01-02');
      expect((r as Error).failure, isA<NetworkFailure>());
    });

    test('ServerException -> ServerFailure keeping its message', () async {
      when(
        () => remote.getAyah(any(), any()),
      ).thenThrow(const ServerException('upstream down'));
      when(
        () => remote.getHadith(any(), any()),
      ).thenAnswer((_) async => _hadithModel);
      final f = ((await repo.fetch('2024-01-02')) as Error).failure;
      expect(f, isA<ServerFailure>());
      expect(f.message, 'upstream down');
    });

    test('ServerException without message uses friendly default', () async {
      when(
        () => remote.getAyah(any(), any()),
      ).thenThrow(const ServerException());
      when(
        () => remote.getHadith(any(), any()),
      ).thenAnswer((_) async => _hadithModel);
      final f = ((await repo.fetch('2024-01-02')) as Error).failure;
      expect(f, isA<ServerFailure>());
      expect(f.message, isNotEmpty);
    });

    test('unexpected error -> UnexpectedFailure and nothing cached', () async {
      when(() => remote.getAyah(any(), any())).thenThrow(StateError('x'));
      when(
        () => remote.getHadith(any(), any()),
      ).thenAnswer((_) async => _hadithModel);
      final r = await repo.fetch('2024-01-02');
      expect((r as Error).failure, isA<UnexpectedFailure>());
      expect(repo.getCached('2024-01-02'), isNull);
    });

    test('pruneBefore delegates to store', () async {
      await store.writeContent('2025-01-01', _ayah, _hadithModel);
      await store.writeContent('2025-02-01', _ayah, _hadithModel);
      await repo.pruneBefore('2025-01-15');
      expect(repo.getCached('2025-01-01'), isNull);
      expect(repo.getCached('2025-02-01'), isNotNull);
    });

    test('selector and repository agree on dateKey for a given day', () async {
      stubRemote();
      final key = DailyContentSelector.dateKey(DateTime(2025, 5, 5));
      final r = await repo.fetch(key);
      expect((r as Success<DailyContent>).data.dateKey, key);
    });
  });
}
