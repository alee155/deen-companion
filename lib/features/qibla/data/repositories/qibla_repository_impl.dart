import '../../../../core/cache/hive_cache_store.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/location/location_service.dart';
import '../../../../core/network/network_info.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../../core/utils/logger.dart';
import '../../domain/entities/qibla_info.dart';
import '../../domain/repositories/qibla_repository.dart';
import '../datasources/qibla_remote_datasource.dart';
import '../models/qibla_info_model.dart';

class QiblaRepositoryImpl implements QiblaRepository {
  final QiblaRemoteDataSource remoteDataSource;
  final LocationService locationService;
  final HiveCacheStore cacheStore;
  final NetworkInfo networkInfo;

  const QiblaRepositoryImpl({
    required this.remoteDataSource,
    required this.locationService,
    required this.cacheStore,
    required this.networkInfo,
  });

  static const _cacheTtl = Duration(days: 7);

  // Rounded to ~1.1km precision — moving a short distance doesn't change
  // Qibla bearing meaningfully, so this keeps the cache useful without
  // pretending sub-meter precision matters here.
  String _cacheKey(double lat, double lng) {
    final roundedLat = (lat * 100).round() / 100;
    final roundedLng = (lng * 100).round() / 100;
    return 'qibla_${roundedLat}_$roundedLng';
  }

  @override
  Future<Result<QiblaInfo>> getQiblaForCurrentLocation({
    bool forceRefresh = false,
  }) async {
    Coordinates coordinates;
    try {
      coordinates = await locationService.getCurrentCoordinates();
    } on LocationServiceException catch (e) {
      return Error(LocationFailure(e.message));
    }

    final key = _cacheKey(coordinates.latitude, coordinates.longitude);

    if (!forceRefresh) {
      final cached = cacheStore.read(key, QiblaInfoModel.fromJson);
      if (cached != null && !cached.isStale(_cacheTtl))
        return Success(cached.data.toEntity());
    }

    if (!await networkInfo.isConnected) {
      final cached = cacheStore.read(key, QiblaInfoModel.fromJson);
      if (cached != null) return Success(cached.data.toEntity());
      return const Error(NetworkFailure());
    }

    try {
      final model = await remoteDataSource.getQibla(
        coordinates.latitude,
        coordinates.longitude,
      );
      await cacheStore.save(key, model, (m) => m.toJson());
      return Success(model.toEntity());
    } on ServerException catch (e) {
      final cached = cacheStore.read(key, QiblaInfoModel.fromJson);
      if (cached != null) return Success(cached.data.toEntity());
      return Error(
        ServerFailure(
          e.message ?? 'Something went wrong on our end. Try again.',
        ),
      );
    } catch (e, stackTrace) {
      AppLogger.e('QiblaRepository: unexpected error', e, stackTrace);
      return const Error(UnexpectedFailure());
    }
  }
}
