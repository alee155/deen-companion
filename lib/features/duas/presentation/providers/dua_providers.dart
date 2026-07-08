import 'dart:async';
import 'package:deen_companion/core/cache/hive_cache_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/di/providers.dart';
import '../../data/datasources/dua_remote_datasource.dart';
import '../../data/repositories/dua_repository_impl.dart';
import '../../domain/entities/dua.dart';
import '../../domain/entities/duas_bundle.dart';
import '../../domain/repositories/dua_repository.dart';

final duaRemoteDataSourceProvider = Provider<DuaRemoteDataSource>((ref) {
  return DuaRemoteDataSourceImpl(ref.watch(dioProvider));
});

final duaRepositoryProvider = Provider<DuaRepository>((ref) {
  return DuaRepositoryImpl(
    remoteDataSource: ref.watch(duaRemoteDataSourceProvider),
    cacheStore: ref.watch(hiveCacheStoreProvider),
    networkInfo: ref.watch(networkInfoProvider),
  );
});

class DuasBundleNotifier extends StreamNotifier<DuasBundle> {
  @override
  Stream<DuasBundle> build() async* {
    final repository = ref.watch(duaRepositoryProvider);
    final cached = repository.getCachedBundle();
    if (cached != null) yield cached;

    final result = await repository.fetchAndCacheBundle();
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

final duasBundleNotifierProvider =
    StreamNotifierProvider<DuasBundleNotifier, DuasBundle>(
      DuasBundleNotifier.new,
    );

class DuaSearchNotifier extends AsyncNotifier<List<Dua>?> {
  @override
  FutureOr<List<Dua>?> build() => null;

  Future<void> search(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      state = const AsyncData(null);
      return;
    }
    state = const AsyncLoading();
    final result = await ref.read(duaRepositoryProvider).search(trimmed);
    state = result.when(
      success: (data) => AsyncData(data),
      failure: (failure) => AsyncError(failure, StackTrace.current),
    );
  }
}

final duaSearchNotifierProvider =
    AsyncNotifierProvider<DuaSearchNotifier, List<Dua>?>(DuaSearchNotifier.new);
