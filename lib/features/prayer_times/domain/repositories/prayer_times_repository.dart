import '../../../../core/usecase/usecase.dart';
import '../entities/prayer_times.dart';

abstract class PrayerTimesRepository {
  Future<Result<PrayerTimes>> getPrayerTimesForCurrentLocation();
}
