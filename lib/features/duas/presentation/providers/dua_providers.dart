import 'dart:async';
import 'package:deen_companion/core/cache/hive_cache_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/cache/cache_first_stream_notifier.dart';
import '../../../../core/di/providers.dart';
import '../../data/datasources/dua_remote_datasource.dart';
import '../../data/repositories/dua_repository_impl.dart';
import '../../domain/dua_urdu_texts.dart';
import 'dua_urdu_providers.dart';
import '../../domain/entities/dua.dart';
import '../../domain/entities/duas_bundle.dart';
import '../../domain/repositories/dua_repository.dart';
import '../../../../core/usecase/usecase.dart';

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

class DuasBundleNotifier extends CacheFirstStreamNotifier<DuasBundle> {
  @override
  DuasBundle? readCache() => ref.read(duaRepositoryProvider).getCachedBundle();

  @override
  Future<Result<DuasBundle>> fetchFresh() =>
      ref.read(duaRepositoryProvider).fetchAndCacheBundle();
}

final duasBundleNotifierProvider =
    StreamNotifierProvider<DuasBundleNotifier, DuasBundle>(
      DuasBundleNotifier.new,
    );

class DuaSearchNotifier extends AsyncNotifier<List<Dua>?> {
  static final _urduScript = RegExp(r'[؀-ۿݐ-ݿﭐ-﷿ﹰ-﻿]');

  @override
  FutureOr<List<Dua>?> build() => null;

  Future<void> _searchUrdu(String query) async {
    final texts = await ref
        .read(duaUrduTextsProvider.future)
        .catchError((_) => DuaUrduTexts.empty);
    final bundle = await ref.read(duaRepositoryProvider).fetchAndCacheBundle();
    state = bundle.when(
      success: (b) {
        final categoryOf = {for (final d in b.duas) d.id: d.category};
        final ids = texts.search(query, categoryOf: categoryOf);
        final byId = {for (final d in b.duas) d.id: d};
        return AsyncData([for (final id in ids) ?byId[id]]);
      },
      failure: (failure) => AsyncError(failure, StackTrace.current),
    );
  }

  Future<void> search(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      state = const AsyncData(null);
      return;
    }
    state = const AsyncLoading();
    // The source only reads English. Urdu is searched in the Urdu that ships
    // with the app, whichever language is shown.
    if (_urduScript.hasMatch(trimmed)) {
      await _searchUrdu(trimmed);
      return;
    }
    final result = await ref.read(duaRepositoryProvider).search(trimmed);
    state = result.when(
      success: (data) => AsyncData(data),
      failure: (failure) => AsyncError(failure, StackTrace.current),
    );
  }
}

final duaSearchNotifierProvider =
    AsyncNotifierProvider<DuaSearchNotifier, List<Dua>?>(DuaSearchNotifier.new);
