import '../../../../core/cache/hive_cache_store.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/location/location_service.dart';
import '../../../../core/network/network_info.dart';
import '../../../../core/usecase/usecase.dart';
import '../../domain/entities/prayer_times.dart';
import '../../domain/repositories/prayer_times_repository.dart';
import '../datasources/prayer_times_remote_datasource.dart';
import '../models/prayer_times_model.dart';

/// Single cache key — we only ever remember prayer times for the user's
/// most recent location, not a history of locations.
const _cacheKey = 'prayer_times_last_known';

class PrayerTimesRepositoryImpl implements PrayerTimesRepository {
  final PrayerTimesRemoteDataSource remoteDataSource;
  final LocationService locationService;
  final HiveCacheStore cacheStore;
  final NetworkInfo networkInfo;

  const PrayerTimesRepositoryImpl({
    required this.remoteDataSource,
    required this.locationService,
    required this.cacheStore,
    required this.networkInfo,
  });

  @override
  PrayerTimes? getCachedPrayerTimesForLastKnownLocation() {
    final cached = cacheStore.read<PrayerTimesModel>(
      _cacheKey,
      PrayerTimesModel.fromJson,
    );
    return cached?.data.toEntity();
  }

  @override
  Future<Result<PrayerTimes>> fetchAndCachePrayerTimes({
    bool forceRefresh = false,
  }) async {
    if (!await networkInfo.isConnected) {
      return const Error(NetworkFailure());
    }

    try {
      final coordinates = await locationService.getCurrentCoordinates();
      final model = await remoteDataSource.getTimings(coordinates);

      await cacheStore.save<PrayerTimesModel>(
        _cacheKey,
        model,
        (m) => m.toJson(),
      );

      return Success(model.toEntity());
    } on LocationServiceException catch (e) {
      return Error(LocationFailure(e.message));
    } on ServerException {
      return const Error(ServerFailure());
    } on NetworkException {
      return const Error(NetworkFailure());
    } catch (_) {
      return const Error(UnexpectedFailure());
    }
  }
}
