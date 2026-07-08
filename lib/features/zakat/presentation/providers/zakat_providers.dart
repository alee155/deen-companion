import 'dart:async';
import 'package:deen_companion/core/cache/hive_cache_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/di/providers.dart';
import '../../data/datasources/zakat_remote_datasource.dart';
import '../../data/repositories/zakat_repository_impl.dart';
import '../../domain/entities/zakat_calculation.dart';
import '../../domain/entities/zakat_info.dart';
import '../../domain/repositories/zakat_repository.dart';

final zakatRemoteDataSourceProvider = Provider<ZakatRemoteDataSource>((ref) {
  return ZakatRemoteDataSourceImpl(ref.watch(dioProvider));
});

final zakatRepositoryProvider = Provider<ZakatRepository>((ref) {
  return ZakatRepositoryImpl(
    remoteDataSource: ref.watch(zakatRemoteDataSourceProvider),
    cacheStore: ref.watch(hiveCacheStoreProvider),
    networkInfo: ref.watch(networkInfoProvider),
  );
});

class ZakatInfoNotifier extends StreamNotifier<ZakatInfo> {
  @override
  Stream<ZakatInfo> build() async* {
    final repository = ref.watch(zakatRepositoryProvider);
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

final zakatInfoNotifierProvider =
    StreamNotifierProvider<ZakatInfoNotifier, ZakatInfo>(ZakatInfoNotifier.new);

class ZakatCalculatorNotifier extends AsyncNotifier<ZakatCalculationResult?> {
  @override
  FutureOr<ZakatCalculationResult?> build() => null;

  Future<void> calculate(ZakatCalculationInput input) async {
    state = const AsyncLoading();
    final result = await ref.read(zakatRepositoryProvider).calculate(input);
    state = result.when(
      success: (d) => AsyncData(d),
      failure: (f) => AsyncError(f, StackTrace.current),
    );
  }

  void reset() => state = const AsyncData(null);
}

final zakatCalculatorNotifierProvider =
    AsyncNotifierProvider<ZakatCalculatorNotifier, ZakatCalculationResult?>(
      ZakatCalculatorNotifier.new,
    );

class AgricultureZakatNotifier extends AsyncNotifier<AgricultureZakatResult?> {
  @override
  FutureOr<AgricultureZakatResult?> build() => null;

  Future<void> calculate(double value, WaterSource waterSource) async {
    state = const AsyncLoading();
    final result = await ref
        .read(zakatRepositoryProvider)
        .calculateAgriculture(value, waterSource);
    state = result.when(
      success: (d) => AsyncData(d),
      failure: (f) => AsyncError(f, StackTrace.current),
    );
  }
}

final agricultureZakatNotifierProvider =
    AsyncNotifierProvider<AgricultureZakatNotifier, AgricultureZakatResult?>(
      AgricultureZakatNotifier.new,
    );
