import 'dart:async';
import 'package:deen_companion/core/cache/hive_cache_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/cache/cache_first_stream_notifier.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/error/failures.dart';
import '../../data/datasources/hadith_remote_datasource.dart';
import '../../data/repositories/hadith_repository_impl.dart';
import '../../domain/entities/hadith.dart';
import '../../domain/entities/hadith_collection.dart';
import '../../domain/hadith_search_query.dart';
import '../../domain/repositories/hadith_repository.dart';
import '../../../../core/usecase/usecase.dart';

final hadithRemoteDataSourceProvider = Provider<HadithRemoteDataSource>((ref) {
  return HadithRemoteDataSourceImpl(ref.watch(dioProvider));
});

final hadithRepositoryProvider = Provider<HadithRepository>((ref) {
  return HadithRepositoryImpl(
    remoteDataSource: ref.watch(hadithRemoteDataSourceProvider),
    cacheStore: ref.watch(hiveCacheStoreProvider),
    networkInfo: ref.watch(networkInfoProvider),
  );
});

// ── Collections — cache-first stream, same shape as Quran meta ──

class HadithCollectionsNotifier
    extends CacheFirstStreamNotifier<List<HadithCollection>> {
  @override
  List<HadithCollection>? readCache() =>
      ref.read(hadithRepositoryProvider).getCachedCollections();

  @override
  Future<Result<List<HadithCollection>>> fetchFresh() =>
      ref.read(hadithRepositoryProvider).fetchAndCacheCollections();
}

final hadithCollectionsNotifierProvider =
    StreamNotifierProvider<HadithCollectionsNotifier, List<HadithCollection>>(
      HadithCollectionsNotifier.new,
    );

/// The metadata for one collection, or null while the list is still loading.
///
/// Screens reached by collection *key* alone (the reader, opened from a route
/// parameter or a deep link) use this to show the real book identity — proper
/// name, Arabic title, compiler — instead of a generic "Hadith" header.
final hadithCollectionByKeyProvider =
    Provider.family<HadithCollection?, String>((ref, key) {
      final collections = ref.watch(hadithCollectionsNotifierProvider).value;
      if (collections == null) return null;
      for (final collection in collections) {
        if (collection.key == key) return collection;
      }
      return null;
    });

// ── Paginated hadith list, family by collection key ──

class HadithListState {
  final List<Hadith> hadiths;
  final int page;
  final int totalPages;
  final bool isLoadingMore;

  const HadithListState({
    this.hadiths = const [],
    this.page = 0,
    this.totalPages = 1,
    this.isLoadingMore = false,
  });

  bool get hasMore => page < totalPages;

  HadithListState copyWith({
    List<Hadith>? hadiths,
    int? page,
    int? totalPages,
    bool? isLoadingMore,
  }) {
    return HadithListState(
      hadiths: hadiths ?? this.hadiths,
      page: page ?? this.page,
      totalPages: totalPages ?? this.totalPages,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }
}

class HadithListNotifier extends FamilyStreamNotifier<HadithListState, String> {
  @override
  Stream<HadithListState> build(String collectionKey) async* {
    final repository = ref.read(hadithRepositoryProvider);

    final cachedPage1 = repository.getCachedHadithPage(collectionKey, 1);
    HadithListState? cachedState;
    if (cachedPage1 != null) {
      cachedState = HadithListState(
        hadiths: cachedPage1.hadiths,
        page: cachedPage1.page,
        totalPages: cachedPage1.totalPages,
      );
      yield cachedState;
    }

    try {
      final fresh = await _loadPage(collectionKey, 1, existing: const []);
      yield fresh;
    } catch (_) {
      // A failed background refresh shouldn't clear content that's
      // already on screen — if we had nothing cached to begin with,
      // rethrow so the screen can show its real error state.
      if (cachedState == null) rethrow;
    }
  }

  Future<HadithListState> _loadPage(
    String collectionKey,
    int page, {
    required List<Hadith> existing,
  }) async {
    final repository = ref.read(hadithRepositoryProvider);
    final result = await repository.fetchAndCacheHadithPage(
      collectionKey,
      page,
    );
    return result.when(
      success: (pageResult) => HadithListState(
        hadiths: [...existing, ...pageResult.hadiths],
        page: pageResult.page,
        totalPages: pageResult.totalPages,
      ),
      failure: (failure) {
        if (existing.isNotEmpty) {
          return HadithListState(
            hadiths: existing,
            page: page - 1,
            totalPages: page,
          );
        }
        throw failure;
      },
    );
  }

  Future<void> loadMore(String collectionKey) async {
    final current = state.value;
    if (current == null || !current.hasMore || current.isLoadingMore) return;

    state = AsyncData(current.copyWith(isLoadingMore: true));
    final next = await _loadPage(
      collectionKey,
      current.page + 1,
      existing: current.hadiths,
    );
    state = AsyncData(next.copyWith(isLoadingMore: false));
  }
}

final hadithListNotifierProvider =
    StreamNotifierProvider.family<HadithListNotifier, HadithListState, String>(
      HadithListNotifier.new,
    );

// ── Daily hadith — keepAlive, date-based caching handled in repository ──

class DailyHadithNotifier extends AsyncNotifier<Hadith> {
  @override
  Future<Hadith> build() async {
    final result = await ref.watch(hadithRepositoryProvider).fetchDailyHadith();
    return result.when(success: (h) => h, failure: (failure) => throw failure);
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}

final dailyHadithNotifierProvider =
    AsyncNotifierProvider<DailyHadithNotifier, Hadith>(DailyHadithNotifier.new);

// ── Search ──

/// How the results of a search were found.
enum HadithSearchMode {
  /// The words as an exact phrase, which is how the source matches.
  exact,

  /// No hadith has the words as a phrase, so these contain all of the words,
  /// in any order.
  allWords,

  /// A hadith number was typed with a book chosen: the one hadith with it.
  number,
}

/// What a search was for and how it went — what the screen needs to explain
/// the results (or the lack of them) to the reader.
class HadithSearchInfo {
  final HadithSearchQuery query;

  /// The book searched, or null for all of them.
  final String? collection;
  final HadithSearchMode mode;

  /// Some book returned as many as it was asked for, so there may be more.
  final bool mayHaveMore;

  const HadithSearchInfo({
    required this.query,
    required this.collection,
    this.mode = HadithSearchMode.exact,
    this.mayHaveMore = false,
  });
}

final hadithSearchInfoProvider = StateProvider<HadithSearchInfo?>(
  (ref) => null,
);

typedef _Found = ({List<Hadith> hadiths, bool mayHaveMore});

/// Searches the hadith for what the reader typed.
///
/// The source matches the English text only, as an exact phrase, and returns
/// its hits book by book, so a plain search for "charity" would come back as
/// 100 hadith from Bukhari and nothing from the other books. So:
///  * an all-books search asks every book for a few hits and mixes them;
///  * a phrase nobody wrote is retried as "all of these words, any order";
///  * Urdu is searched by the English word of the topic it names.
class HadithSearchNotifier extends AsyncNotifier<List<Hadith>?> {
  /// Every collection, searched one by one for an all-books search.
  static const allCollections = [
    'bukhari',
    'muslim',
    'abudawud',
    'tirmidhi',
    'ibnmajah',
    'nasai',
    'malik',
    'nawawi',
    'qudsi',
    'dehlawi',
  ];

  /// Hits asked of each book in an all-books search.
  static const perBook = 6;

  /// Candidates asked of each book when retrying as "all the words": enough to
  /// find a hadith holding every word, few enough to stay quick.
  static const wordFetch = 40;

  /// Most results shown for a "contains all the words" retry.
  static const wordResultCap = 40;

  /// The most a single-book search returns (the repository's default).
  static const singleBookLimit = 25;

  int _latest = 0;

  @override
  FutureOr<List<Hadith>?> build() => null;

  void _setInfo(HadithSearchInfo? info) =>
      ref.read(hadithSearchInfoProvider.notifier).state = info;

  Future<void> search(String input, {String? collection}) async {
    final query = HadithSearchQuery.parse(input);
    final id = ++_latest;

    if (query.isEmpty) {
      state = const AsyncData(null);
      _setInfo(null);
      return;
    }
    // A number with a book chosen is a hadith number, not a word.
    final number = query.number;
    if (number != null && collection != null) {
      await _byNumber(query, number, collection, id);
      return;
    }
    // Only words the search can't read (e.g. Urdu that isn't a known topic).
    if (!query.isSearchable) {
      state = const AsyncData(<Hadith>[]);
      _setInfo(HadithSearchInfo(query: query, collection: collection));
      return;
    }

    state = const AsyncLoading();
    _setInfo(null);

    final exact = await _exact(query.term, collection);
    if (exact.failure != null) {
      if (id == _latest) {
        state = AsyncError(exact.failure!, StackTrace.current);
      }
      return;
    }

    var hadiths = exact.found!.hadiths;
    var mayHaveMore = exact.found!.mayHaveMore;
    var mode = HadithSearchMode.exact;

    // Nobody wrote these words as one phrase; look for hadith containing all
    // of them instead, so a few keywords in any order still find something.
    if (hadiths.isEmpty && query.isMultiWord) {
      final relaxed = await _allWords(query.words, collection);
      if (relaxed.isNotEmpty) {
        hadiths = relaxed;
        mayHaveMore = false;
        mode = HadithSearchMode.allWords;
      }
    }

    if (id != _latest) return; // a newer search has taken over
    state = AsyncData(hadiths);
    _setInfo(
      HadithSearchInfo(
        query: query,
        collection: collection,
        mode: mode,
        mayHaveMore: mayHaveMore,
      ),
    );
  }

  Future<void> _byNumber(
    HadithSearchQuery query,
    int number,
    String collection,
    int id,
  ) async {
    state = const AsyncLoading();
    _setInfo(null);
    final result = await ref
        .read(hadithRepositoryProvider)
        .findByNumber(collection, number);
    if (id != _latest) return;
    result.when(
      success: (hadith) {
        state = AsyncData(hadith == null ? <Hadith>[] : [hadith]);
        _setInfo(
          HadithSearchInfo(
            query: query,
            collection: collection,
            mode: HadithSearchMode.number,
          ),
        );
      },
      failure: (failure) => state = AsyncError(failure, StackTrace.current),
    );
  }

  /// The phrase as the source matches it. In one book that is a single search;
  /// across all books each book is asked for a few and the hits are mixed, so
  /// the first screen isn't one book.
  Future<({_Found? found, Failure? failure})> _exact(
    String term,
    String? collection,
  ) async {
    final repository = ref.read(hadithRepositoryProvider);

    if (collection != null) {
      final result = await repository.search(term, collection: collection);
      return result.when(
        success: (data) => (
          found: (hadiths: data, mayHaveMore: data.length >= singleBookLimit),
          failure: null,
        ),
        failure: (failure) => (found: null, failure: failure),
      );
    }

    final results = await Future.wait([
      for (final key in allCollections)
        repository.search(term, collection: key, limit: perBook),
    ]);
    final perBookHits = <List<Hadith>>[];
    Failure? firstFailure;
    for (final result in results) {
      result.when(
        success: perBookHits.add,
        failure: (failure) => firstFailure ??= failure,
      );
    }
    // A book that failed just contributes nothing, but if every book failed
    // the search has failed.
    if (perBookHits.isEmpty) return (found: null, failure: firstFailure);

    return (
      found: (
        hadiths: _interleave(perBookHits),
        mayHaveMore: perBookHits.any((hits) => hits.length >= perBook),
      ),
      failure: null,
    );
  }

  /// Hadith containing every one of [words], in any order. The source can only
  /// be asked for one phrase, so it is asked for the longest word (the least
  /// common, usually) and the rest are checked here.
  Future<List<Hadith>> _allWords(List<String> words, String? collection) async {
    final repository = ref.read(hadithRepositoryProvider);
    final anchor = ([
      ...words,
    ]..sort((a, b) => b.length.compareTo(a.length))).first;
    final keys = collection != null ? [collection] : allCollections;

    final results = await Future.wait([
      for (final key in keys)
        repository.search(anchor, collection: key, limit: wordFetch),
    ]);

    final lowered = [for (final w in words) w.toLowerCase()];
    final perBookHits = <List<Hadith>>[];
    for (final result in results) {
      result.when(
        success: (data) => perBookHits.add([
          for (final hadith in data)
            if (lowered.every((w) => hadith.english.toLowerCase().contains(w)))
              hadith,
        ]),
        failure: (_) {},
      );
    }
    return _interleave(perBookHits).take(wordResultCap).toList();
  }

  /// One from each book in turn, so the top of the list spans the books.
  static List<Hadith> _interleave(List<List<Hadith>> lists) {
    final out = <Hadith>[];
    var i = 0;
    var added = true;
    while (added) {
      added = false;
      for (final list in lists) {
        if (i < list.length) {
          out.add(list[i]);
          added = true;
        }
      }
      i++;
    }
    return out;
  }
}

final hadithSearchNotifierProvider =
    AsyncNotifierProvider<HadithSearchNotifier, List<Hadith>?>(
      HadithSearchNotifier.new,
    );
