import 'dart:async';
import 'package:deen_companion/core/cache/hive_cache_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/di/providers.dart';
import '../../data/datasources/hadith_remote_datasource.dart';
import '../../data/repositories/hadith_repository_impl.dart';
import '../../domain/entities/hadith.dart';
import '../../domain/entities/hadith_collection.dart';
import '../../domain/repositories/hadith_repository.dart';

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

class HadithCollectionsNotifier extends StreamNotifier<List<HadithCollection>> {
  @override
  Stream<List<HadithCollection>> build() async* {
    final repository = ref.watch(hadithRepositoryProvider);
    final cached = repository.getCachedCollections();
    if (cached != null) yield cached;

    final result = await repository.fetchAndCacheCollections();
    final fresh = result.when(
      success: (data) => data,
      failure: (failure) {
        if (cached == null) throw failure;
        return null;
      },
    );
    if (fresh != null) yield fresh;
  }
}

final hadithCollectionsNotifierProvider =
    StreamNotifierProvider<HadithCollectionsNotifier, List<HadithCollection>>(
      HadithCollectionsNotifier.new,
    );

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

class HadithListNotifier extends FamilyAsyncNotifier<HadithListState, String> {
  @override
  Future<HadithListState> build(String collectionKey) {
    return _loadPage(collectionKey, 1, existing: const []);
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
        if (existing.isNotEmpty)
          return HadithListState(
            hadiths: existing,
            page: page - 1,
            totalPages: page,
          );
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
    AsyncNotifierProvider.family<HadithListNotifier, HadithListState, String>(
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

// ── Search — action-triggered, same pattern as Quran search ──

class HadithSearchNotifier extends AsyncNotifier<List<Hadith>?> {
  @override
  FutureOr<List<Hadith>?> build() => null;

  Future<void> search(String query, {String? collection}) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      state = const AsyncData(null);
      return;
    }
    state = const AsyncLoading();
    final result = await ref
        .read(hadithRepositoryProvider)
        .search(trimmed, collection: collection);
    state = result.when(
      success: (data) => AsyncData(data),
      failure: (failure) => AsyncError(failure, StackTrace.current),
    );
  }
}

final hadithSearchNotifierProvider =
    AsyncNotifierProvider<HadithSearchNotifier, List<Hadith>?>(
      HadithSearchNotifier.new,
    );
