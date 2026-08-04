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
    required int method,
    required int school,
    bool forceRefresh = false,
  }) async {
    // Location is resolved *before* the connectivity check on purpose: a
    // disabled GPS toggle is a different problem from a dead connection, and
    // checking network first meant a location problem was reported to the
    // user as "You're offline. Check your connection."
    final Coordinates coordinates;
    try {
      coordinates = await locationService.getCurrentCoordinates();
    } on LocationServiceException catch (e) {
      return Error(LocationFailure(e.kind, e.message));
    }

    if (!await networkInfo.isConnected) {
      final cached = getCachedPrayerTimesForLastKnownLocation();
      if (cached != null) return Success(cached);
      return const Error(NetworkFailure());
    }

    try {
      final model = await remoteDataSource.getTimings(
        coordinates,
        method: method,
        school: school,
      );

      await cacheStore.save<PrayerTimesModel>(
        _cacheKey,
        model,
        (m) => m.toJson(),
      );

      return Success(model.toEntity());
    } on ServerException {
      return const Error(ServerFailure());
    } on NetworkException {
      return const Error(NetworkFailure());
    } catch (_) {
      return const Error(UnexpectedFailure());
    }
  }

  @override
  Future<Result<List<PrayerTimes>>> fetchMonthCalendar({
    required int year,
    required int month,
    required int method,
    required int school,
  }) async {
    final Coordinates coordinates;
    try {
      coordinates = await locationService.getCurrentCoordinates();
    } on LocationServiceException catch (e) {
      return Error(LocationFailure(e.kind, e.message));
    }

    if (!await networkInfo.isConnected) {
      return const Error(NetworkFailure());
    }

    try {
      final models = await remoteDataSource.getMonthCalendar(
        coordinates,
        year: year,
        month: month,
        method: method,
        school: school,
      );
      return Success(models.map((m) => m.toEntity()).toList());
    } on ServerException {
      return const Error(ServerFailure());
    } on NetworkException {
      return const Error(NetworkFailure());
    } catch (_) {
      return const Error(UnexpectedFailure());
    }
  }
}
