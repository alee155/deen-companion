import '../../../../core/usecase/usecase.dart';
import '../entities/asma_daily.dart';
import '../entities/asma_name.dart';

abstract class AsmaUlHusnaRepository {
  List<AsmaName>? getCachedAllNames();
  Future<Result<List<AsmaName>>> fetchAndCacheAllNames({
    bool forceRefresh = false,
  });
  Future<Result<AsmaDaily>> fetchDailyNames(
    int dayNumber, {
    bool forceRefresh = false,
  });
  Future<Result<List<AsmaName>>> search(String query);
}
