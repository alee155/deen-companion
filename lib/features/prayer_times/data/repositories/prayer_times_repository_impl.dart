import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/location/location_service.dart';
import '../../../../core/network/network_info.dart';
import '../../../../core/usecase/usecase.dart';
import '../../domain/entities/prayer_times.dart';
import '../../domain/repositories/prayer_times_repository.dart';
import '../datasources/prayer_times_remote_datasource.dart';

class PrayerTimesRepositoryImpl implements PrayerTimesRepository {
  final PrayerTimesRemoteDataSource remoteDataSource;
  final LocationService locationService;
  final NetworkInfo networkInfo;

  const PrayerTimesRepositoryImpl({
    required this.remoteDataSource,
    required this.locationService,
    required this.networkInfo,
  });

  @override
  Future<Result<PrayerTimes>> getPrayerTimesForCurrentLocation() async {
    if (!await networkInfo.isConnected) {
      return const Error(NetworkFailure());
    }

    try {
      final coordinates = await locationService.getCurrentCoordinates();
      final model = await remoteDataSource.getTimings(coordinates);
      return Success(model.toEntity);
    } on LocationServiceException catch (e) {
      return Error(LocationFailure(e.message));
    } on ServerException catch (e) {
      return Error(
        ServerFailure(
          e.message ?? 'Something went wrong on our end. Try again.',
        ),
      );
    } catch (_) {
      return const Error(UnexpectedFailure());
    }
  }
}
