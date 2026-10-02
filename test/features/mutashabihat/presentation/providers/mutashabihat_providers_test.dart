import 'package:deen_companion/core/error/failures.dart';
import 'package:deen_companion/core/usecase/usecase.dart';
import 'package:deen_companion/features/mutashabihat/domain/entities/mutashabihat_entry.dart';
import 'package:deen_companion/features/mutashabihat/domain/entities/mutashabihat_info.dart';
import 'package:deen_companion/features/mutashabihat/domain/entities/mutashabihat_surah_page.dart';
import 'package:deen_companion/features/mutashabihat/domain/entities/mutashabihat_verse_ref.dart';
import 'package:deen_companion/features/mutashabihat/domain/repositories/mutashabihat_repository.dart';
import 'package:deen_companion/features/mutashabihat/presentation/providers/mutashabihat_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockRepo extends Mock implements MutashabihatRepository {}

MutashabihatVerseRef ref(String key) => MutashabihatVerseRef(
  verseKey: key,
  surah: 1,
  ayah: 1,
  surahNameArabic: 'a',
  surahNameEnglish: 'e',
  arabic: 'ar',
  translation: 't',
);

MutashabihatEntry entry(String key) =>
    MutashabihatEntry(verse: ref(key), similarVerses: [ref('9:9')]);

MutashabihatSurahPage page(int p, int total, {int count = 2}) =>
    MutashabihatSurahPage(
      surah: 2,
      surahNameArabic: 'a',
      surahNameEnglish: 'e',
      total: 10,
      page: p,
      limit: 2,
      totalPages: total,
      entries: [for (var i = 0; i < count; i++) entry('2:${p * 10 + i}')],
    );

void main() {
  late MockRepo repo;
  late ProviderContainer container;

  setUp(() {
    repo = MockRepo();
    container = ProviderContainer(
      overrides: [mutashabihatRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
  });

  test('info notifier: no cache + failure errors with the Failure', () async {
    when(() => repo.getCachedInfo()).thenReturn(null);
    when(
      () => repo.fetchAndCacheInfo(),
    ).thenAnswer((_) async => const Error(NetworkFailure()));

    final sub = container.listen(mutashabihatInfoNotifierProvider, (_, _) {});
    await pumpEventQueue();
    expect(sub.read().error, isA<NetworkFailure>());
  });

  test('info notifier: emits fetched info', () async {
    const info = MutashabihatInfo(
      description: 'd',
      totalEntries: 1,
      totalPairs: 2,
      surahsInvolved: 3,
      source: 's',
      attribution: 'a',
    );
    when(() => repo.getCachedInfo()).thenReturn(null);
    when(
      () => repo.fetchAndCacheInfo(),
    ).thenAnswer((_) async => const Success(info));
    expect(await container.read(mutashabihatInfoNotifierProvider.future), info);
  });

  group('random notifier', () {
    test('loads an entry on build', () async {
      when(
        () => repo.fetchRandom(),
      ).thenAnswer((_) async => Success(entry('1:1')));
      expect(
        (await container.read(
          mutashabihatRandomNotifierProvider.future,
        ))!.verse.verseKey,
        '1:1',
      );
    });

    test('next() goes loading then new entry', () async {
      var n = 0;
      when(
        () => repo.fetchRandom(),
      ).thenAnswer((_) async => Success(entry('1:${++n}')));
      container.listen(mutashabihatRandomNotifierProvider, (_, _) {});
      await container.read(mutashabihatRandomNotifierProvider.future);

      final states = <AsyncValue<MutashabihatEntry?>>[];
      container.listen(
        mutashabihatRandomNotifierProvider,
        (_, s) => states.add(s),
      );
      await container.read(mutashabihatRandomNotifierProvider.notifier).next();

      expect(states.first.isLoading, isTrue);
      expect(states.last.value!.verse.verseKey, '1:2');
    });

    test('next() failure becomes AsyncError instead of throwing', () async {
      when(
        () => repo.fetchRandom(),
      ).thenAnswer((_) async => Success(entry('1:1')));
      container.listen(mutashabihatRandomNotifierProvider, (_, _) {});
      await container.read(mutashabihatRandomNotifierProvider.future);

      when(
        () => repo.fetchRandom(),
      ).thenAnswer((_) async => const Error(NetworkFailure()));
      await container.read(mutashabihatRandomNotifierProvider.notifier).next();

      expect(
        container.read(mutashabihatRandomNotifierProvider).error,
        isA<NetworkFailure>(),
      );
    });
  });

  group('by-ayah notifier', () {
    test('passes surah and ayah from the record argument', () async {
      when(
        () => repo.fetchByAyah(2, 255),
      ).thenAnswer((_) async => Success(entry('2:255')));
      final e = await container.read(
        mutashabihatByAyahNotifierProvider((2, 255)).future,
      );
      expect(e.verse.verseKey, '2:255');
    });

    test('NotFoundFailure is surfaced as the error', () async {
      when(
        () => repo.fetchByAyah(any(), any()),
      ).thenAnswer((_) async => const Error(NotFoundFailure('none')));
      await expectLater(
        container.read(mutashabihatByAyahNotifierProvider((1, 1)).future),
        throwsA(isA<NotFoundFailure>()),
      );
    });
  });

  group('surah page notifier', () {
    test('build loads page 1', () async {
      when(
        () => repo.fetchSurahPage(2, 1),
      ).thenAnswer((_) async => Success(page(1, 3)));
      final p = await container.read(
        mutashabihatSurahPageNotifierProvider(2).future,
      );
      expect(p.page, 1);
      expect(p.entries, hasLength(2));
    });

    test('loadMore appends entries and adopts the new paging info', () async {
      when(
        () => repo.fetchSurahPage(2, 1),
      ).thenAnswer((_) async => Success(page(1, 2)));
      when(
        () => repo.fetchSurahPage(2, 2),
      ).thenAnswer((_) async => Success(page(2, 2, count: 1)));
      container.listen(mutashabihatSurahPageNotifierProvider(2), (_, _) {});
      await container.read(mutashabihatSurahPageNotifierProvider(2).future);

      await container
          .read(mutashabihatSurahPageNotifierProvider(2).notifier)
          .loadMore(2);

      final p = container.read(mutashabihatSurahPageNotifierProvider(2)).value!;
      expect(p.entries.map((e) => e.verse.verseKey), ['2:10', '2:11', '2:20']);
      expect(p.page, 2);
      expect(p.hasMore, isFalse);
    });

    test('loadMore does nothing when there are no more pages', () async {
      when(
        () => repo.fetchSurahPage(2, 1),
      ).thenAnswer((_) async => Success(page(1, 1)));
      container.listen(mutashabihatSurahPageNotifierProvider(2), (_, _) {});
      await container.read(mutashabihatSurahPageNotifierProvider(2).future);

      await container
          .read(mutashabihatSurahPageNotifierProvider(2).notifier)
          .loadMore(2);

      verify(() => repo.fetchSurahPage(2, 1)).called(1);
      verifyNever(() => repo.fetchSurahPage(2, 2));
    });

    test(
      'loadMore failure throws (caller sees the Failure) and keeps current state',
      () async {
        when(
          () => repo.fetchSurahPage(2, 1),
        ).thenAnswer((_) async => Success(page(1, 3)));
        when(
          () => repo.fetchSurahPage(2, 2),
        ).thenAnswer((_) async => const Error(NetworkFailure()));
        container.listen(mutashabihatSurahPageNotifierProvider(2), (_, _) {});
        await container.read(mutashabihatSurahPageNotifierProvider(2).future);

        await expectLater(
          container
              .read(mutashabihatSurahPageNotifierProvider(2).notifier)
              .loadMore(2),
          throwsA(isA<NetworkFailure>()),
        );
        expect(
          container
              .read(mutashabihatSurahPageNotifierProvider(2))
              .value!
              .entries,
          hasLength(2),
        );
      },
    );

    test('initial load failure surfaces as error', () async {
      when(
        () => repo.fetchSurahPage(any(), any()),
      ).thenAnswer((_) async => const Error(ServerFailure()));
      await expectLater(
        container.read(mutashabihatSurahPageNotifierProvider(2).future),
        throwsA(isA<ServerFailure>()),
      );
    });
  });
}
