import 'dart:async';
import 'package:deen_companion/core/cache/hive_cache_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/di/providers.dart';
import '../../data/datasources/quran_remote_datasource.dart';
import '../../data/repositories/quran_repository_impl.dart';
import '../../domain/entities/juz.dart';
import '../../domain/entities/mushaf_page.dart';
import '../../domain/entities/quran_meta.dart';
import '../../domain/entities/search_result.dart';
import '../../domain/entities/surah_summary.dart';
import '../../domain/repositories/quran_repository.dart';

final quranRemoteDataSourceProvider = Provider<QuranRemoteDataSource>((ref) {
  return QuranRemoteDataSourceImpl(ref.watch(dioProvider));
});

final quranRepositoryProvider = Provider<QuranRepository>((ref) {
  return QuranRepositoryImpl(
    remoteDataSource: ref.watch(quranRemoteDataSourceProvider),
    cacheStore: ref.watch(hiveCacheStoreProvider),
    networkInfo: ref.watch(networkInfoProvider),
  );
});

// ── Quran meta — cache-first stream ──

class QuranMetaNotifier extends StreamNotifier<QuranMeta> {
  @override
  Stream<QuranMeta> build() async* {
    final repository = ref.watch(quranRepositoryProvider);

    final cached = repository.getCachedQuranMeta();
    if (cached != null) yield cached;

    final result = await repository.fetchAndCacheQuranMeta();
    final fresh = result.when(
      success: (data) => data,
      failure: (failure) {
        if (cached == null) throw failure;
        return null;
      },
    );
    if (fresh != null) yield fresh;
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}

final quranMetaNotifierProvider =
    StreamNotifierProvider<QuranMetaNotifier, QuranMeta>(QuranMetaNotifier.new);

// ── Surah list ──

class SurahListNotifier extends StreamNotifier<List<SurahSummary>> {
  @override
  Stream<List<SurahSummary>> build() async* {
    final repository = ref.watch(quranRepositoryProvider);

    final cached = repository.getCachedSurahList();
    if (cached != null) yield cached;

    final result = await repository.fetchAndCacheSurahList();
    final fresh = result.when(
      success: (data) => data,
      failure: (failure) {
        if (cached == null) throw failure;
        return null;
      },
    );
    if (fresh != null) yield fresh;
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}

final surahListNotifierProvider =
    StreamNotifierProvider<SurahListNotifier, List<SurahSummary>>(
      SurahListNotifier.new,
    );

// ── Juz — family ──

class JuzNotifier extends FamilyStreamNotifier<Juz, int> {
  @override
  Stream<Juz> build(int arg) async* {
    final repository = ref.watch(quranRepositoryProvider);

    final cached = repository.getCachedJuz(arg);
    if (cached != null) yield cached;

    final result = await repository.fetchAndCacheJuz(arg);
    final fresh = result.when(
      success: (data) => data,
      failure: (failure) {
        if (cached == null) throw failure;
        return null;
      },
    );
    if (fresh != null) yield fresh;
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}

final juzNotifierProvider =
    StreamNotifierProvider.family<JuzNotifier, Juz, int>(JuzNotifier.new);

// ── Mushaf page — family ──

class MushafPageNotifier extends FamilyStreamNotifier<MushafPage, int> {
  @override
  Stream<MushafPage> build(int arg) async* {
    final repository = ref.watch(quranRepositoryProvider);

    final cached = repository.getCachedMushafPage(arg);
    if (cached != null) yield cached;

    final result = await repository.fetchAndCacheMushafPage(arg);
    final fresh = result.when(
      success: (data) => data,
      failure: (failure) {
        if (cached == null) throw failure;
        return null;
      },
    );
    if (fresh != null) yield fresh;
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}

final mushafPageNotifierProvider =
    StreamNotifierProvider.family<MushafPageNotifier, MushafPage, int>(
      MushafPageNotifier.new,
    );

// ── Search — action-triggered, plain AsyncNotifier ──

class QuranSearchNotifier extends AsyncNotifier<List<SearchResult>?> {
  @override
  FutureOr<List<SearchResult>?> build() => null;

  Future<void> search(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      state = const AsyncData(null);
      return;
    }

    state = const AsyncLoading();
    final repository = ref.read(quranRepositoryProvider);
    final result = await repository.search(trimmed);
    state = result.when(
      success: (data) => AsyncData(data),
      failure: (failure) => AsyncError(failure, StackTrace.current),
    );
  }
}

final quranSearchNotifierProvider =
    AsyncNotifierProvider<QuranSearchNotifier, List<SearchResult>?>(
      QuranSearchNotifier.new,
    );
