import '../../../../core/usecase/usecase.dart';
import '../entities/hadith.dart';
import '../entities/hadith_collection.dart';

class HadithPageResult {
  final List<Hadith> hadiths;
  final int page;
  final int totalPages;

  const HadithPageResult({
    required this.hadiths,
    required this.page,
    required this.totalPages,
  });
}

abstract class HadithRepository {
  List<HadithCollection>? getCachedCollections();
  Future<Result<List<HadithCollection>>> fetchAndCacheCollections({
    bool forceRefresh = false,
  });

  Future<Result<HadithPageResult>> fetchAndCacheHadithPage(
    String collection,
    int page, {
    bool forceRefresh = false,
  });

  /// One random hadith per calendar day — cached with the date it was
  /// fetched for, reused all day, refreshed automatically once the
  /// date rolls over. No extra network call on repeat app opens today.
  Future<Result<Hadith>> fetchDailyHadith();

  Future<Result<List<Hadith>>> search(
    String query, {
    String? collection,
    int limit = 25,
  });
}
