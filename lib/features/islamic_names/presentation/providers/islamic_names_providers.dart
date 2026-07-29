import 'package:deen_companion/core/cache/hive_cache_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/cache/cache_first_stream_notifier.dart';
import '../../../../core/di/providers.dart';
import '../../data/datasources/islamic_names_remote_datasource.dart';
import '../../data/repositories/islamic_names_repository_impl.dart';
import '../../domain/entities/islamic_name.dart';
import '../../domain/repositories/islamic_names_repository.dart';
import '../../../../core/usecase/usecase.dart';

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

class IslamicNamesNotifier extends CacheFirstStreamNotifier<List<IslamicName>> {
  @override
  List<IslamicName>? readCache() =>
      ref.read(islamicNamesRepositoryProvider).getCachedNames();

  @override
  Future<Result<List<IslamicName>>> fetchFresh() =>
      ref.read(islamicNamesRepositoryProvider).fetchAndCacheNames();
}

final islamicNamesNotifierProvider =
    StreamNotifierProvider<IslamicNamesNotifier, List<IslamicName>>(
      IslamicNamesNotifier.new,
    );
