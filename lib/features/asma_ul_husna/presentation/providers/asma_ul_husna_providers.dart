import 'dart:async';
import 'package:deen_companion/core/cache/hive_cache_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/cache/cache_first_stream_notifier.dart';
import '../../../../core/di/providers.dart';
import '../../data/datasources/asma_ul_husna_remote_datasource.dart';
import '../../data/repositories/asma_ul_husna_repository_impl.dart';
import '../../domain/entities/asma_daily.dart';
import '../../domain/entities/asma_name.dart';
import '../../domain/repositories/asma_ul_husna_repository.dart';
import '../../../../core/usecase/usecase.dart';

final asmaRemoteDataSourceProvider = Provider<AsmaUlHusnaRemoteDataSource>((
  ref,
) {
  return AsmaUlHusnaRemoteDataSourceImpl(ref.watch(dioProvider));
});

final asmaRepositoryProvider = Provider<AsmaUlHusnaRepository>((ref) {
  return AsmaUlHusnaRepositoryImpl(
    remoteDataSource: ref.watch(asmaRemoteDataSourceProvider),
    cacheStore: ref.watch(hiveCacheStoreProvider),
    networkInfo: ref.watch(networkInfoProvider),
  );
});

class AsmaAllNamesNotifier extends CacheFirstStreamNotifier<List<AsmaName>> {
  @override
  List<AsmaName>? readCache() =>
      ref.read(asmaRepositoryProvider).getCachedAllNames();

  @override
  Future<Result<List<AsmaName>>> fetchFresh() =>
      ref.read(asmaRepositoryProvider).fetchAndCacheAllNames();
}

final asmaAllNamesNotifierProvider =
    StreamNotifierProvider<AsmaAllNamesNotifier, List<AsmaName>>(
      AsmaAllNamesNotifier.new,
    );

class AsmaDailyNotifier extends FamilyAsyncNotifier<AsmaDaily, int> {
  @override
  Future<AsmaDaily> build(int dayNumber) async {
    final result = await ref
        .watch(asmaRepositoryProvider)
        .fetchDailyNames(dayNumber);
    return result.when(success: (d) => d, failure: (f) => throw f);
  }
}

final asmaDailyNotifierProvider =
    AsyncNotifierProvider.family<AsmaDailyNotifier, AsmaDaily, int>(
      AsmaDailyNotifier.new,
    );

class AsmaSearchNotifier extends AsyncNotifier<List<AsmaName>?> {
  @override
  FutureOr<List<AsmaName>?> build() => null;

  Future<void> search(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      state = const AsyncData(null);
      return;
    }
    state = const AsyncLoading();
    final result = await ref.read(asmaRepositoryProvider).search(trimmed);
    state = result.when(
      success: (d) => AsyncData(d),
      failure: (f) => AsyncError(f, StackTrace.current),
    );
  }
}

final asmaSearchNotifierProvider =
    AsyncNotifierProvider<AsmaSearchNotifier, List<AsmaName>?>(
      AsmaSearchNotifier.new,
    );
