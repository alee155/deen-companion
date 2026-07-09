import '../../../../core/usecase/usecase.dart';
import '../entities/islamic_name.dart';

abstract class IslamicNamesRepository {
  List<IslamicName>? getCachedNames();
  Future<Result<List<IslamicName>>> fetchAndCacheNames({
    bool forceRefresh = false,
  });
}
