import '../../../../core/usecase/usecase.dart';
import '../entities/dua.dart';
import '../entities/duas_bundle.dart';

abstract class DuaRepository {
  DuasBundle? getCachedBundle();
  Future<Result<DuasBundle>> fetchAndCacheBundle({bool forceRefresh = false});
  Future<Result<List<Dua>>> search(String query);
}
