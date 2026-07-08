import '../../../../core/usecase/usecase.dart';
import '../entities/prayer_times.dart';
import '../repositories/prayer_times_repository.dart';

class GetPrayerTimes implements UseCase<PrayerTimes, NoParams> {
  final PrayerTimesRepository repository;
  const GetPrayerTimes(this.repository);

  @override
  Future<Result<PrayerTimes>> call(NoParams params) {
    return repository.getPrayerTimesForCurrentLocation();
  }
}
