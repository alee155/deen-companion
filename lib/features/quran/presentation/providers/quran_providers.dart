import 'dart:async';
import 'package:deen_companion/core/cache/hive_cache_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/cache/cache_first_stream_notifier.dart';
import '../../../../core/di/providers.dart';
import '../../data/datasources/quran_remote_datasource.dart';
import '../../data/repositories/quran_repository_impl.dart';
import '../../domain/entities/juz.dart';
import '../../domain/entities/mushaf_page.dart';
import '../../domain/entities/quran_meta.dart';
import '../../domain/entities/search_result.dart';
import '../../domain/entities/surah_summary.dart';
import '../../domain/repositories/quran_repository.dart';
import '../../../../core/usecase/usecase.dart';

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

class QuranMetaNotifier extends CacheFirstStreamNotifier<QuranMeta> {
  @override
  QuranMeta? readCache() =>
      ref.read(quranRepositoryProvider).getCachedQuranMeta();

  @override
  Future<Result<QuranMeta>> fetchFresh() =>
      ref.read(quranRepositoryProvider).fetchAndCacheQuranMeta();

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}

final quranMetaNotifierProvider =
    StreamNotifierProvider<QuranMetaNotifier, QuranMeta>(QuranMetaNotifier.new);

// ── Surah list ──

class SurahListNotifier extends CacheFirstStreamNotifier<List<SurahSummary>> {
  @override
  List<SurahSummary>? readCache() =>
      ref.read(quranRepositoryProvider).getCachedSurahList();

  @override
  Future<Result<List<SurahSummary>>> fetchFresh() =>
      ref.read(quranRepositoryProvider).fetchAndCacheSurahList();

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

class JuzNotifier extends FamilyCacheFirstStreamNotifier<Juz, int> {
  @override
  Juz? readCache(int arg) =>
      ref.read(quranRepositoryProvider).getCachedJuz(arg);

  @override
  Future<Result<Juz>> fetchFresh(int arg) =>
      ref.read(quranRepositoryProvider).fetchAndCacheJuz(arg);

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}

final juzNotifierProvider =
    StreamNotifierProvider.family<JuzNotifier, Juz, int>(JuzNotifier.new);

// ── Mushaf page — family ──

class MushafPageNotifier
    extends FamilyCacheFirstStreamNotifier<MushafPage, int> {
  @override
  MushafPage? readCache(int arg) =>
      ref.read(quranRepositoryProvider).getCachedMushafPage(arg);

  @override
  Future<Result<MushafPage>> fetchFresh(int arg) =>
      ref.read(quranRepositoryProvider).fetchAndCacheMushafPage(arg);

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
