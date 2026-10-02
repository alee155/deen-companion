import 'package:deen_companion/core/error/failures.dart';
import 'package:deen_companion/core/usecase/usecase.dart';
import 'package:deen_companion/features/quran/domain/entities/juz.dart';
import 'package:deen_companion/features/quran/domain/entities/mushaf_page.dart';
import 'package:deen_companion/features/quran/domain/entities/quran_meta.dart';
import 'package:deen_companion/features/quran/domain/entities/search_result.dart';
import 'package:deen_companion/features/quran/domain/entities/surah_summary.dart';
import 'package:deen_companion/features/quran/domain/repositories/quran_repository.dart';
import 'package:deen_companion/features/quran/presentation/providers/last_read_surah_provider.dart';
import 'package:deen_companion/features/quran/presentation/providers/quran_providers.dart';
import 'package:deen_companion/features/recent_activity/domain/entities/recent_activity_item.dart';
import 'package:deen_companion/features/recent_activity/presentation/providers/recent_activity_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockRepo extends Mock implements QuranRepository {}

SurahSummary surah(int n) => SurahSummary(
  number: n,
  nameArabic: 'ع$n',
  nameEnglish: 'Surah $n',
  nameTranslation: 't',
  revelationPlace: 'Makkah',
  versesCount: 10,
  bismillahPre: true,
  exampleAudioUrl: 'u$n',
);

const meta = QuranMeta(
  totalSurahs: 114,
  totalVerses: 6236,
  totalJuzs: 30,
  totalPages: 604,
  textType: 'uthmani',
  translationsAvailable: ['x'],
  reciters: [],
);

const juz1 = Juz(juzNumber: 1, totalVerses: 0, verses: []);
const page1 = MushafPage(page: 1, totalPages: 604, linesPerPage: 15, words: []);

class _FakeRecent extends RecentActivityNotifier {
  final List<RecentActivityItem> items;
  _FakeRecent(this.items);
  @override
  Stream<List<RecentActivityItem>> build() => Stream.value(items);
}

class _FakeSurahList extends SurahListNotifier {
  final List<SurahSummary> list;
  _FakeSurahList(this.list);
  @override
  Stream<List<SurahSummary>> build() => Stream.value(list);
}

RecentActivityItem activity(RecentActivityType type, String ref) =>
    RecentActivityItem(
      id: '${type.name}:$ref',
      type: type,
      referenceId: ref,
      title: 't',
      route: '/r',
      viewedAt: DateTime(2024),
    );

void main() {
  late MockRepo repo;
  late ProviderContainer container;

  ProviderContainer make([List<Override> extra = const []]) {
    final c = ProviderContainer(
      overrides: [quranRepositoryProvider.overrideWithValue(repo), ...extra],
    );
    addTearDown(c.dispose);
    return c;
  }

  setUp(() {
    repo = MockRepo();
    when(() => repo.getCachedQuranMeta()).thenReturn(null);
    when(() => repo.getCachedSurahList()).thenReturn(null);
    when(() => repo.getCachedJuz(any())).thenReturn(null);
    when(() => repo.getCachedMushafPage(any())).thenReturn(null);
  });

  group('cache-first notifiers', () {
    test('no cache: emits fresh data once fetched', () async {
      when(
        () => repo.fetchAndCacheQuranMeta(),
      ).thenAnswer((_) async => const Success(meta));
      container = make();

      expect(await container.read(quranMetaNotifierProvider.future), meta);
    });

    test('no cache + failure: surfaces the Failure as the error', () async {
      when(
        () => repo.fetchAndCacheQuranMeta(),
      ).thenAnswer((_) async => const Error(NetworkFailure()));
      container = make();

      final sub = container.listen(quranMetaNotifierProvider, (_, _) {});
      await pumpEventQueue();

      expect(sub.read().hasError, isTrue);
      expect(sub.read().error, isA<NetworkFailure>());
    });

    test('cached + failure: keeps showing cached data, no error', () async {
      when(() => repo.getCachedQuranMeta()).thenReturn(meta);
      when(
        () => repo.fetchAndCacheQuranMeta(),
      ).thenAnswer((_) async => const Error(ServerFailure()));
      container = make();

      final sub = container.listen(quranMetaNotifierProvider, (_, _) {});
      await pumpEventQueue();

      expect(sub.read().hasError, isFalse);
      expect(sub.read().value, meta);
    });

    test('cached + identical fresh data emits the value only once', () async {
      when(() => repo.getCachedQuranMeta()).thenReturn(meta);
      when(
        () => repo.fetchAndCacheQuranMeta(),
      ).thenAnswer((_) async => const Success(meta));
      container = make();

      final seen = <QuranMeta>[];
      container.listen(quranMetaNotifierProvider, (_, next) {
        if (next.hasValue) seen.add(next.value!);
      }, fireImmediately: true);
      await pumpEventQueue();

      expect(seen, [meta]);
    });

    test('cached + different fresh data emits cached then fresh', () async {
      const fresh = QuranMeta(
        totalSurahs: 114,
        totalVerses: 1,
        totalJuzs: 30,
        totalPages: 604,
        textType: 'uthmani',
        translationsAvailable: ['x'],
        reciters: [],
      );
      when(() => repo.getCachedQuranMeta()).thenReturn(meta);
      when(
        () => repo.fetchAndCacheQuranMeta(),
      ).thenAnswer((_) async => const Success(fresh));
      container = make();

      final seen = <int>[];
      container.listen(quranMetaNotifierProvider, (_, next) {
        if (next.hasValue) seen.add(next.value!.totalVerses);
      }, fireImmediately: true);
      await pumpEventQueue();

      expect(seen, [6236, 1]);
    });

    test('surah list notifier reads and fetches via repository', () async {
      when(
        () => repo.fetchAndCacheSurahList(),
      ).thenAnswer((_) async => Success([surah(1), surah(2)]));
      container = make();

      final list = await container.read(surahListNotifierProvider.future);
      expect(list.map((s) => s.number), [1, 2]);
    });

    test('refresh() re-runs the fetch', () async {
      when(
        () => repo.fetchAndCacheSurahList(),
      ).thenAnswer((_) async => Success([surah(1)]));
      container = make();
      await container.read(surahListNotifierProvider.future);

      await container.read(surahListNotifierProvider.notifier).refresh();

      verify(() => repo.fetchAndCacheSurahList()).called(2);
    });

    test('juz family passes the argument to repository per instance', () async {
      when(() => repo.fetchAndCacheJuz(any())).thenAnswer(
        (i) async => Success(
          Juz(
            juzNumber: i.positionalArguments.first as int,
            totalVerses: 0,
            verses: const [],
          ),
        ),
      );
      container = make();

      expect(
        (await container.read(juzNotifierProvider(3).future)).juzNumber,
        3,
      );
      expect(
        (await container.read(juzNotifierProvider(4).future)).juzNumber,
        4,
      );
      verify(() => repo.getCachedJuz(3)).called(1);
      verify(() => repo.fetchAndCacheJuz(4)).called(1);
    });

    test(
      'mushaf page family serves cached page then ignores equal fresh',
      () async {
        when(() => repo.getCachedMushafPage(1)).thenReturn(page1);
        when(
          () => repo.fetchAndCacheMushafPage(1),
        ).thenAnswer((_) async => const Success(page1));
        container = make();

        final seen = <MushafPage>[];
        container.listen(mushafPageNotifierProvider(1), (_, n) {
          if (n.hasValue) seen.add(n.value!);
        }, fireImmediately: true);
        await pumpEventQueue();

        expect(seen, [page1]);
      },
    );
  });

  group('QuranSearchNotifier', () {
    const hit = SearchResult(
      verseKey: '2:255',
      surahNumber: 2,
      surahName: 'Al-Baqarah',
      ayah: 255,
      arabic: 'a',
      transliteration: 't',
      translation: 'tr',
    );

    test('initial state is data(null)', () {
      container = make();
      expect(container.read(quranSearchNotifierProvider).value, isNull);
    });

    test('blank query resets to null without calling the repository', () async {
      container = make();
      await container.read(quranSearchNotifierProvider.notifier).search('   ');

      expect(container.read(quranSearchNotifierProvider).value, isNull);
      verifyNever(() => repo.search(any()));
    });

    test('trims the query and exposes results', () async {
      when(
        () => repo.search('throne'),
      ).thenAnswer((_) async => const Success([hit]));
      container = make();

      await container
          .read(quranSearchNotifierProvider.notifier)
          .search('  throne ');

      expect(container.read(quranSearchNotifierProvider).value, [hit]);
      verify(() => repo.search('throne')).called(1);
    });

    test('goes through loading before resolving', () async {
      when(
        () => repo.search(any()),
      ).thenAnswer((_) async => const Success([hit]));
      container = make();
      final states = <AsyncValue<List<SearchResult>?>>[];
      container.listen(quranSearchNotifierProvider, (_, n) => states.add(n));

      await container.read(quranSearchNotifierProvider.notifier).search('a');

      expect(states.first.isLoading, isTrue);
      expect(states.last.value, [hit]);
    });

    test('failure becomes AsyncError carrying the Failure', () async {
      when(
        () => repo.search(any()),
      ).thenAnswer((_) async => const Error(NetworkFailure()));
      container = make();

      await container.read(quranSearchNotifierProvider.notifier).search('a');

      final state = container.read(quranSearchNotifierProvider);
      expect(state.hasError, isTrue);
      expect(state.error, isA<NetworkFailure>());
    });

    test('a later blank search clears earlier results', () async {
      when(
        () => repo.search(any()),
      ).thenAnswer((_) async => const Success([hit]));
      container = make();
      final n = container.read(quranSearchNotifierProvider.notifier);

      await n.search('a');
      await n.search('');

      expect(container.read(quranSearchNotifierProvider).value, isNull);
    });
  });

  group('lastReadSurahProvider', () {
    ProviderContainer withData(
      List<RecentActivityItem> recent,
      List<SurahSummary> surahs,
    ) {
      final c = make([
        recentActivityNotifierProvider.overrideWith(() => _FakeRecent(recent)),
        surahListNotifierProvider.overrideWith(() => _FakeSurahList(surahs)),
      ]);
      // Keep both stream providers alive and let their first events land.
      c.listen(recentActivityNotifierProvider, (_, _) {});
      c.listen(surahListNotifierProvider, (_, _) {});
      return c;
    }

    test('null while nothing has loaded', () {
      container = withData(const [], const []);
      expect(container.read(lastReadSurahProvider), isNull);
    });

    test('null when surahs loaded but no surah activity', () async {
      container = withData(
        [activity(RecentActivityType.hadith, '1')],
        [surah(1)],
      );
      await pumpEventQueue();
      expect(container.read(lastReadSurahProvider), isNull);
    });

    test(
      'picks the first (most recent) surah activity, skipping other types',
      () async {
        container = withData(
          [
            activity(RecentActivityType.dua, '5'),
            activity(RecentActivityType.surah, '2'),
            activity(RecentActivityType.surah, '1'),
          ],
          [surah(1), surah(2), surah(3)],
        );
        await pumpEventQueue();
        expect(container.read(lastReadSurahProvider)?.number, 2);
      },
    );

    test('null when referenceId is not a number', () async {
      container = withData(
        [activity(RecentActivityType.surah, 'abc')],
        [surah(1)],
      );
      await pumpEventQueue();
      expect(container.read(lastReadSurahProvider), isNull);
    });

    test('null when the referenced surah is not in the list', () async {
      container = withData(
        [activity(RecentActivityType.surah, '99')],
        [surah(1)],
      );
      await pumpEventQueue();
      expect(container.read(lastReadSurahProvider), isNull);
    });
  });
}
