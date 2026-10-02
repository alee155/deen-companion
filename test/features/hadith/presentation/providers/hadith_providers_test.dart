import 'package:deen_companion/core/error/failures.dart';
import 'package:deen_companion/core/usecase/usecase.dart';
import 'package:deen_companion/features/hadith/domain/entities/hadith.dart';
import 'package:deen_companion/features/hadith/domain/entities/hadith_collection.dart';
import 'package:deen_companion/features/hadith/domain/repositories/hadith_repository.dart';
import 'package:deen_companion/features/hadith/presentation/providers/hadith_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockRepo extends Mock implements HadithRepository {}

Hadith hadith(int n) => Hadith(
  id: 'b:$n',
  collection: 'b',
  collectionName: 'B',
  hadithNumber: n,
  arabic: 'a',
  english: 'e',
  grade: 'Sahih',
);

HadithCollection coll(String key) => HadithCollection(
  key: key,
  name: key,
  arabicName: key,
  author: 'a',
  reliability: 'r',
  totalHadiths: 1,
);

HadithPageResult page(int p, int total, {int count = 2}) => HadithPageResult(
  hadiths: [for (var i = 0; i < count; i++) hadith(p * 100 + i)],
  page: p,
  totalPages: total,
);

void main() {
  late MockRepo repo;
  late ProviderContainer container;

  setUp(() {
    repo = MockRepo();
    when(() => repo.getCachedCollections()).thenReturn(null);
    when(() => repo.getCachedHadithPage(any(), any())).thenReturn(null);
    container = ProviderContainer(
      overrides: [hadithRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
  });

  group('HadithListState', () {
    test('defaults: empty, page 0, hasMore true until totalPages reached', () {
      const s = HadithListState();
      expect(s.hadiths, isEmpty);
      expect(s.hasMore, isTrue); // 0 < 1
      expect(const HadithListState(page: 3, totalPages: 3).hasMore, isFalse);
      expect(const HadithListState(page: 4, totalPages: 3).hasMore, isFalse);
    });

    test('copyWith overrides only provided fields', () {
      final s = HadithListState(hadiths: [hadith(1)], page: 1, totalPages: 4);
      final c = s.copyWith(isLoadingMore: true);
      expect(c.isLoadingMore, isTrue);
      expect(c.page, 1);
      expect(c.hadiths, hasLength(1));
    });
  });

  group('hadithCollectionByKeyProvider', () {
    test('null while collections have not loaded', () {
      when(
        () => repo.fetchAndCacheCollections(),
      ).thenAnswer((_) async => const Success(<HadithCollection>[]));
      expect(container.read(hadithCollectionByKeyProvider('bukhari')), isNull);
    });

    test(
      'finds the collection by key and returns null for unknown keys',
      () async {
        when(
          () => repo.fetchAndCacheCollections(),
        ).thenAnswer((_) async => Success([coll('bukhari'), coll('muslim')]));
        container.listen(hadithCollectionsNotifierProvider, (_, _) {});
        await container.read(hadithCollectionsNotifierProvider.future);

        expect(
          container.read(hadithCollectionByKeyProvider('muslim'))?.key,
          'muslim',
        );
        expect(container.read(hadithCollectionByKeyProvider('nope')), isNull);
      },
    );
  });

  group('HadithListNotifier', () {
    test('no cache: loads page 1 from the repository', () async {
      when(
        () => repo.fetchAndCacheHadithPage('b', 1),
      ).thenAnswer((_) async => Success(page(1, 3)));

      final s = await container.read(hadithListNotifierProvider('b').future);

      expect(s.hadiths, hasLength(2));
      expect(s.page, 1);
      expect(s.hasMore, isTrue);
    });

    test('emits cached page 1 first, then fresh', () async {
      when(
        () => repo.getCachedHadithPage('b', 1),
      ).thenReturn(page(1, 3, count: 1));
      when(
        () => repo.fetchAndCacheHadithPage('b', 1),
      ).thenAnswer((_) async => Success(page(1, 3, count: 2)));

      final counts = <int>[];
      container.listen(hadithListNotifierProvider('b'), (_, n) {
        if (n.hasValue) counts.add(n.value!.hadiths.length);
      }, fireImmediately: true);
      await pumpEventQueue();

      expect(counts, [1, 2]);
    });

    test('no cache + failure: error is the Failure', () async {
      when(
        () => repo.fetchAndCacheHadithPage('b', 1),
      ).thenAnswer((_) async => const Error(NetworkFailure()));

      final sub = container.listen(hadithListNotifierProvider('b'), (_, _) {});
      await pumpEventQueue();

      expect(sub.read().error, isA<NetworkFailure>());
    });

    test('cached + failure: cached content stays, no error', () async {
      when(() => repo.getCachedHadithPage('b', 1)).thenReturn(page(1, 3));
      when(
        () => repo.fetchAndCacheHadithPage('b', 1),
      ).thenAnswer((_) async => const Error(NetworkFailure()));

      final sub = container.listen(hadithListNotifierProvider('b'), (_, _) {});
      await pumpEventQueue();

      expect(sub.read().hasError, isFalse);
      expect(sub.read().value!.hadiths, hasLength(2));
    });

    test('loadMore appends the next page and updates paging', () async {
      when(
        () => repo.fetchAndCacheHadithPage('b', 1),
      ).thenAnswer((_) async => Success(page(1, 2)));
      when(
        () => repo.fetchAndCacheHadithPage('b', 2),
      ).thenAnswer((_) async => Success(page(2, 2, count: 1)));
      container.listen(hadithListNotifierProvider('b'), (_, _) {});
      await container.read(hadithListNotifierProvider('b').future);

      await container
          .read(hadithListNotifierProvider('b').notifier)
          .loadMore('b');

      final s = container.read(hadithListNotifierProvider('b')).value!;
      expect(s.hadiths.map((h) => h.hadithNumber), [100, 101, 200]);
      expect(s.page, 2);
      expect(s.hasMore, isFalse);
      expect(s.isLoadingMore, isFalse);
    });

    test('loadMore is a no-op on the last page', () async {
      when(
        () => repo.fetchAndCacheHadithPage('b', 1),
      ).thenAnswer((_) async => Success(page(1, 1)));
      container.listen(hadithListNotifierProvider('b'), (_, _) {});
      await container.read(hadithListNotifierProvider('b').future);

      await container
          .read(hadithListNotifierProvider('b').notifier)
          .loadMore('b');

      verify(() => repo.fetchAndCacheHadithPage('b', 1)).called(1);
      verifyNever(() => repo.fetchAndCacheHadithPage('b', 2));
    });

    test(
      'loadMore failure keeps existing hadiths and leaves hasMore true for retry',
      () async {
        when(
          () => repo.fetchAndCacheHadithPage('b', 1),
        ).thenAnswer((_) async => Success(page(1, 3)));
        when(
          () => repo.fetchAndCacheHadithPage('b', 2),
        ).thenAnswer((_) async => const Error(NetworkFailure()));
        container.listen(hadithListNotifierProvider('b'), (_, _) {});
        await container.read(hadithListNotifierProvider('b').future);

        await container
            .read(hadithListNotifierProvider('b').notifier)
            .loadMore('b');

        final s = container.read(hadithListNotifierProvider('b')).value!;
        expect(s.hadiths, hasLength(2));
        expect(s.page, 1);
        expect(s.hasMore, isTrue);
        expect(s.isLoadingMore, isFalse);
      },
    );

    test('collections are independent per key', () async {
      when(
        () => repo.fetchAndCacheHadithPage(any(), any()),
      ).thenAnswer((_) async => Success(page(1, 1)));
      await container.read(hadithListNotifierProvider('b').future);
      await container.read(hadithListNotifierProvider('m').future);

      verify(() => repo.fetchAndCacheHadithPage('b', 1)).called(1);
      verify(() => repo.fetchAndCacheHadithPage('m', 1)).called(1);
    });
  });

  group('DailyHadithNotifier', () {
    test('resolves to the hadith on success', () async {
      when(
        () => repo.fetchDailyHadith(),
      ).thenAnswer((_) async => Success(hadith(1)));
      expect(
        (await container.read(dailyHadithNotifierProvider.future)).hadithNumber,
        1,
      );
    });

    test('failure surfaces as the provider error', () async {
      when(
        () => repo.fetchDailyHadith(),
      ).thenAnswer((_) async => const Error(ServerFailure('x')));
      await expectLater(
        container.read(dailyHadithNotifierProvider.future),
        throwsA(isA<ServerFailure>()),
      );
    });

    test('refresh re-fetches', () async {
      var n = 0;
      when(
        () => repo.fetchDailyHadith(),
      ).thenAnswer((_) async => Success(hadith(++n)));
      container.listen(dailyHadithNotifierProvider, (_, _) {});
      await container.read(dailyHadithNotifierProvider.future);

      await container.read(dailyHadithNotifierProvider.notifier).refresh();

      expect(
        container.read(dailyHadithNotifierProvider).value!.hadithNumber,
        2,
      );
    });
  });

  group('HadithSearchNotifier', () {
    test('blank query resets and does not search', () async {
      await container.read(hadithSearchNotifierProvider.notifier).search('   ');
      expect(container.read(hadithSearchNotifierProvider).value, isNull);
      verifyNever(
        () => repo.search(any(), collection: any(named: 'collection')),
      );
    });

    test('forwards trimmed query and collection', () async {
      when(
        () => repo.search('intent', collection: 'muslim'),
      ).thenAnswer((_) async => Success([hadith(1)]));
      await container
          .read(hadithSearchNotifierProvider.notifier)
          .search(' intent ', collection: 'muslim');
      expect(container.read(hadithSearchNotifierProvider).value, hasLength(1));
    });

    test('failure becomes AsyncError(Failure)', () async {
      when(
        () => repo.search(any(), collection: any(named: 'collection')),
      ).thenAnswer((_) async => const Error(NetworkFailure()));
      await container.read(hadithSearchNotifierProvider.notifier).search('a');
      expect(
        container.read(hadithSearchNotifierProvider).error,
        isA<NetworkFailure>(),
      );
    });
  });
}
