import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/location/location_service.dart';
import '../../../../core/usecase/usecase.dart';
import '../../data/datasources/prayer_times_remote_datasource.dart';
import '../../data/repositories/prayer_times_repository_impl.dart';
import '../../domain/entities/prayer_times.dart';
import '../../domain/repositories/prayer_times_repository.dart';
import '../../domain/usecases/get_prayer_times.dart';

final prayerTimesRemoteDataSourceProvider =
    Provider<PrayerTimesRemoteDataSource>((ref) {
      return PrayerTimesRemoteDataSourceImpl(ref.watch(dioProvider));
    });

final prayerTimesRepositoryProvider = Provider<PrayerTimesRepository>((ref) {
  return PrayerTimesRepositoryImpl(
    remoteDataSource: ref.watch(prayerTimesRemoteDataSourceProvider),
    locationService: ref.watch(locationServiceProvider),
    networkInfo: ref.watch(networkInfoProvider),
  );
});

final getPrayerTimesUseCaseProvider = Provider<GetPrayerTimes>((ref) {
  return GetPrayerTimes(ref.watch(prayerTimesRepositoryProvider));
});

class PrayerTimesNotifier extends AsyncNotifier<PrayerTimes> {
  @override
  Future<PrayerTimes> build() async {
    final result = await ref
        .watch(getPrayerTimesUseCaseProvider)
        .call(NoParams());
    return result.when(
      success: (data) => data,
      failure: (failure) => throw failure,
    );
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}

final prayerTimesNotifierProvider =
    AsyncNotifierProvider<PrayerTimesNotifier, PrayerTimes>(
      PrayerTimesNotifier.new,
    );
