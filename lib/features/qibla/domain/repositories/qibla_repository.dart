import '../../../../core/usecase/usecase.dart';
import '../entities/qibla_info.dart';

abstract class QiblaRepository {
  Future<Result<QiblaInfo>> getQiblaForCurrentLocation({
    bool forceRefresh = false,
  });
}
