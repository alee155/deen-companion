import 'package:deen_companion/core/cache/hive_cache_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/di/providers.dart';
import '../../data/datasources/mutashabihat_remote_datasource.dart';
import '../../data/repositories/mutashabihat_repository_impl.dart';
import '../../domain/entities/mutashabihat_entry.dart';
import '../../domain/entities/mutashabihat_info.dart';
import '../../domain/entities/mutashabihat_surah_page.dart';
import '../../domain/repositories/mutashabihat_repository.dart';

final mutashabihatRemoteDataSourceProvider =
    Provider<MutashabihatRemoteDataSource>((ref) {
      return MutashabihatRemoteDataSourceImpl(ref.watch(dioProvider));
    });

final mutashabihatRepositoryProvider = Provider<MutashabihatRepository>((ref) {
  return MutashabihatRepositoryImpl(
    remoteDataSource: ref.watch(mutashabihatRemoteDataSourceProvider),
    cacheStore: ref.watch(hiveCacheStoreProvider),
    networkInfo: ref.watch(networkInfoProvider),
  );
});

class MutashabihatInfoNotifier extends StreamNotifier<MutashabihatInfo> {
  @override
  Stream<MutashabihatInfo> build() async* {
    final repository = ref.watch(mutashabihatRepositoryProvider);
    final cached = repository.getCachedInfo();
    if (cached != null) yield cached;

    final result = await repository.fetchAndCacheInfo();
    final fresh = result.when(
      success: (d) => d,
      failure: (f) {
        if (cached == null) throw f;
        return null;
      },
    );
    if (fresh != null) yield fresh;
  }
}

final mutashabihatInfoNotifierProvider =
    StreamNotifierProvider<MutashabihatInfoNotifier, MutashabihatInfo>(
      MutashabihatInfoNotifier.new,
    );

class MutashabihatRandomNotifier extends AsyncNotifier<MutashabihatEntry?> {
  @override
  Future<MutashabihatEntry?> build() => _fetch();

  Future<MutashabihatEntry> _fetch() async {
    final result = await ref.read(mutashabihatRepositoryProvider).fetchRandom();
    return result.when(success: (d) => d, failure: (f) => throw f);
  }

  Future<void> next() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }
}

final mutashabihatRandomNotifierProvider =
    AsyncNotifierProvider<MutashabihatRandomNotifier, MutashabihatEntry?>(
      MutashabihatRandomNotifier.new,
    );

class MutashabihatByAyahNotifier
    extends FamilyAsyncNotifier<MutashabihatEntry, (int, int)> {
  @override
  Future<MutashabihatEntry> build((int, int) arg) async {
    final result = await ref
        .watch(mutashabihatRepositoryProvider)
        .fetchByAyah(arg.$1, arg.$2);
    return result.when(success: (d) => d, failure: (f) => throw f);
  }
}

final mutashabihatByAyahNotifierProvider =
    AsyncNotifierProvider.family<
      MutashabihatByAyahNotifier,
      MutashabihatEntry,
      (int, int)
    >(MutashabihatByAyahNotifier.new);

class MutashabihatSurahPageNotifier
    extends FamilyAsyncNotifier<MutashabihatSurahPage, int> {
  @override
  Future<MutashabihatSurahPage> build(int surah) => _loadPage(surah, 1);

  Future<MutashabihatSurahPage> _loadPage(int surah, int page) async {
    final result = await ref
        .read(mutashabihatRepositoryProvider)
        .fetchSurahPage(surah, page);
    return result.when(success: (d) => d, failure: (f) => throw f);
  }

  Future<void> loadMore(int surah) async {
    final current = state.value;
    if (current == null || !current.hasMore) return;
    final next = await _loadPage(surah, current.page + 1);
    state = AsyncData(
      MutashabihatSurahPage(
        surah: next.surah,
        surahNameArabic: next.surahNameArabic,
        surahNameEnglish: next.surahNameEnglish,
        total: next.total,
        page: next.page,
        limit: next.limit,
        totalPages: next.totalPages,
        entries: [...current.entries, ...next.entries],
      ),
    );
  }
}

final mutashabihatSurahPageNotifierProvider =
    AsyncNotifierProvider.family<
      MutashabihatSurahPageNotifier,
      MutashabihatSurahPage,
      int
    >(MutashabihatSurahPageNotifier.new);
