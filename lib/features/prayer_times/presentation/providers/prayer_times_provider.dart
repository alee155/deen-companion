import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/cache/hive_cache_store.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/location/location_service.dart';
import '../../data/datasources/prayer_times_remote_datasource.dart';
import '../../data/repositories/prayer_times_repository_impl.dart';
import '../../domain/entities/prayer_times.dart';
import '../../domain/repositories/prayer_times_repository.dart';

final prayerTimesRemoteDataSourceProvider =
    Provider<PrayerTimesRemoteDataSource>((ref) {
      return PrayerTimesRemoteDataSourceImpl(ref.watch(dioProvider));
    });

final prayerTimesRepositoryProvider = Provider<PrayerTimesRepository>((ref) {
  return PrayerTimesRepositoryImpl(
    remoteDataSource: ref.watch(prayerTimesRemoteDataSourceProvider),
    locationService: ref.watch(locationServiceProvider),
    cacheStore: ref.watch(hiveCacheStoreProvider),
    networkInfo: ref.watch(networkInfoProvider),
  );
});

class PrayerTimesNotifier extends StreamNotifier<PrayerTimes> {
  @override
  Stream<PrayerTimes> build() async* {
    final repository = ref.watch(prayerTimesRepositoryProvider);

    final cached = repository.getCachedPrayerTimesForLastKnownLocation();
    if (cached != null) yield cached;

    final result = await repository.fetchAndCachePrayerTimes();
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

final prayerTimesNotifierProvider =
    StreamNotifierProvider<PrayerTimesNotifier, PrayerTimes>(
      PrayerTimesNotifier.new,
    );
