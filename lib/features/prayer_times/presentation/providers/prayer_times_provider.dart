import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/cache/cache_first_stream_notifier.dart';
import '../../../../core/cache/hive_cache_store.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/location/location_service.dart';
import '../../data/datasources/prayer_times_remote_datasource.dart';
import '../../data/repositories/prayer_times_repository_impl.dart';
import '../../domain/entities/prayer_times.dart';
import '../../domain/repositories/prayer_times_repository.dart';
import 'prayer_calculation_settings_provider.dart';
import 'dart:async';
import '../../../../core/usecase/usecase.dart';

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

class PrayerTimesNotifier extends CacheFirstStreamNotifier<PrayerTimes> {
  @override
  PrayerTimes? readCache() {
    // Watched (not read) so that changing the calculation method or Asr
    // school in Settings automatically triggers a rebuild of this
    // provider — no manual "please refresh now" wiring needed elsewhere.
    ref.watch(prayerCalculationSettingsProvider);
    return ref
        .read(prayerTimesRepositoryProvider)
        .getCachedPrayerTimesForLastKnownLocation();
  }

  @override
  Future<Result<PrayerTimes>> fetchFresh() {
    final settings = ref.read(prayerCalculationSettingsProvider);
    return ref
        .read(prayerTimesRepositoryProvider)
        .fetchAndCachePrayerTimes(
          method: settings.method.id,
          school: settings.school.id,
        );
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

// ── Monthly Prayer Calendar ──

typedef YearMonth = ({int year, int month});

class PrayerCalendarNotifier
    extends FamilyAsyncNotifier<List<PrayerTimes>, YearMonth> {
  @override
  Future<List<PrayerTimes>> build(YearMonth arg) async {
    final settings = ref.watch(prayerCalculationSettingsProvider);
    final result = await ref
        .read(prayerTimesRepositoryProvider)
        .fetchMonthCalendar(
          year: arg.year,
          month: arg.month,
          method: settings.method.id,
          school: settings.school.id,
        );
    return result.when(success: (data) => data, failure: (f) => throw f);
  }
}

final prayerCalendarNotifierProvider =
    AsyncNotifierProvider.family<
      PrayerCalendarNotifier,
      List<PrayerTimes>,
      YearMonth
    >(PrayerCalendarNotifier.new);
