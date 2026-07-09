import 'package:deen_companion/core/cache/hive_cache_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/di/providers.dart';
import '../../data/datasources/islamic_names_remote_datasource.dart';
import '../../data/repositories/islamic_names_repository_impl.dart';
import '../../domain/entities/islamic_name.dart';
import '../../domain/repositories/islamic_names_repository.dart';

final islamicNamesRemoteDataSourceProvider =
    Provider<IslamicNamesRemoteDataSource>((ref) {
      return IslamicNamesRemoteDataSourceImpl(ref.watch(dioProvider));
    });

final islamicNamesRepositoryProvider = Provider<IslamicNamesRepository>((ref) {
  return IslamicNamesRepositoryImpl(
    remoteDataSource: ref.watch(islamicNamesRemoteDataSourceProvider),
    cacheStore: ref.watch(hiveCacheStoreProvider),
    networkInfo: ref.watch(networkInfoProvider),
  );
});

class IslamicNamesNotifier extends StreamNotifier<List<IslamicName>> {
  @override
  Stream<List<IslamicName>> build() async* {
    final repository = ref.watch(islamicNamesRepositoryProvider);
    final cached = repository.getCachedNames();
    if (cached != null) yield cached;

    final result = await repository.fetchAndCacheNames();
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

final islamicNamesNotifierProvider =
    StreamNotifierProvider<IslamicNamesNotifier, List<IslamicName>>(
      IslamicNamesNotifier.new,
    );
